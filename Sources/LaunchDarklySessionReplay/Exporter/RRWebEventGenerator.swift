import Foundation
#if canImport(UIKit)
import UIKit
#endif
import LaunchDarklyObservability
import OSLog
#if !LD_COCOAPODS
import Common
#endif

enum RRWebPlayerConstants {
    // padding requiered by used html dom structure
    static let padding = CGSize(width: 11, height: 11)
    // size limit of accumulated continues canvas operations on the RRWeb player
    static let canvasBufferLimit = 9_000_000 // ~9mb (10mb - 1mb for keyframe logic)
    
    static let canvasDrawEntourage = 300 // bytes
}

actor RRWebEventGenerator {
    enum Dom {
        static let html = "html"
        static let head = "head"
        static let body = "body"
        static let lang = "lang"
        static let en = "en"
        static let style = "style"
        static let bodyStyle = "position:relative;"
    }

    private var title: String
    private let padding = RRWebPlayerConstants.padding
    private var sid = 0
    private var nextSid: Int {
        sid += 1
        return sid
    }
    
    private var id = 16
    private var nextId: Int {
        id += 1
        return id
    }
    private var pushedCanvasSize: Int = 0
    private var generatingCanvasSize: Int = 0
    
    private var imageId: Int?
    private var bodyId: Int?
    private var knownKeyFrameId: Int?
    private var lastImageSize: CGSize?
    private var stats: SessionReplayStats?
    private let isDebug = false
    private var nodeIds: [TileSignature: Int] = [:]
    
    init(log: OSLog, title: String, method _: SessionReplayOptions.CompressionMethod) {
        if isDebug {
            self.stats = SessionReplayStats(log: log)
        }
        self.title = title
    }
    
    func generateEvents(items: [EventQueueItem]) -> [Event] {
        var events = [Event]()
        self.generatingCanvasSize = pushedCanvasSize
        for item in items {
            appendEvents(item: item, events: &events)
        }
        
        return events
    }
    
    func generateWakeUpEvents(items: [EventQueueItem]) -> [Event] {
        var events = [Event]()
        if let imageId, let firstItem = items.first {
            events.append(reloadEvent(timestamp: firstItem.timestamp))
            wakeUpPlayerEvents(&events, imageId, firstItem.timestamp)
        }
        return events
    }
    
    fileprivate func wakeUpPlayerEvents(_ events: inout [Event], _ imageId: Int, _ timestamp: TimeInterval) {
        // artificial mouse movement to wake up session replay player
        events.append(Event(type: .IncrementalSnapshot,
                            data: AnyEventData(MouseInteractionData(source: .mouseInteraction,
                                                                    type: .mouseDown,
                                                                    id: imageId,
                                                                    x: padding.width,
                                                                    y: padding.height)),
                            timestamp: timestamp,
                            _sid: nextSid))
        events.append(Event(type: .IncrementalSnapshot,
                            data: AnyEventData(MouseInteractionData(source: .mouseInteraction,
                                                                    type: .mouseUp,
                                                                    id: imageId,
                                                                    x: padding.width,
                                                                    y: padding.height)),
                            timestamp: timestamp,
                            _sid: nextSid))
    }
    
    func appendEvents(item: EventQueueItem, events: inout [Event]) {
        switch item.payload {
        case let payload as ImageItemPayload:
            let exportFrame = payload.exportFrame
            defer {
                lastImageSize = exportFrame.originalSize
            }
            
            stats?.addExportFrame(exportFrame)
            
            let timestamp = item.timestamp
            
            if exportFrame.isKeyframe {
                knownKeyFrameId = exportFrame.keyFrameId
            }
            
            if let bodyId,
               lastImageSize == exportFrame.originalSize,
               (generatingCanvasSize < RRWebPlayerConstants.canvasBufferLimit || !exportFrame.isKeyframe) {
                events.append(contentsOf: addCommandNodes(exportFrame: exportFrame, timestamp: timestamp, bodyId: bodyId))
            } else {
                // if screen changed size we send fullSnapshot as canvas resizing might take to many hours on the server
                appendFullSnapshotEvents(exportFrame, timestamp, &events)
            }
            
        case let interaction as TouchInteraction:
            appendTouchInteraction(interaction: interaction, events: &events)
            
        case let identifyItemPayload as IdentifyItemPayload:
            if let event = identifyEvent(itemPayload: identifyItemPayload) {
                events.append(event)
            }
            
        default:
            break // Item wasn't needed for SessionReplay
        }
    }
    
    func paddedSize(_ size: CGSize) -> CGSize {
        CGSize(width: size.width + padding.width * 2, height: size.height + padding.height * 2)
    }
    
    fileprivate func appendTouchInteraction(interaction: TouchInteraction, events: inout [Event]) {
        if let touchEventData: EventDataProtocol = switch interaction.kind {
        case .touchDown(let point):
            MouseInteractionData(source: .mouseInteraction,
                                 type: .touchStart,
                                 id: imageId,
                                 x: point.x + padding.width,
                                 y: point.y + padding.height)
            
        case .touchUp(let point):
            MouseInteractionData(source: .mouseInteraction,
                                 type: .touchEnd,
                                 id: imageId,
                                 x: point.x + padding.width,
                                 y: point.y + padding.height)
            
        case .touchPath(let points):
            MouseMoveEventData(
                source: .touchMove,
                positions: points.map { p in MouseMoveEventData.Position(
                    x: p.position.x + padding.width,
                    y: p.position.y + padding.height,
                    id: imageId,
                    timeOffset: p.timestamp - interaction.timestamp) })
            
        default:
            Optional<MouseInteractionData>.none
        } {
            let event = Event(type: .IncrementalSnapshot,
                              data: AnyEventData(touchEventData),
                              timestamp: interaction.timestamp,
                              _sid: nextSid)
            events.append(event)
        }
        
        if let clickEvent = clickEvent(interaction: interaction) {
            events.append(clickEvent)
        }
    }
    
    func clickEvent(interaction: TouchInteraction) -> Event? {
        guard case .touchDown = interaction.kind else { return nil }
        
        let eventData = CustomEventData(tag: .click, payload: ClickPayload(
            clickTarget: interaction.target?.className ?? "",
            clickTextContent: interaction.target?.accessibilityIdentifier ?? "",
            clickSelector: interaction.target?.accessibilityIdentifier ?? "view"))
        let event = Event(type: .Custom,
                          data: AnyEventData(eventData),
                          timestamp: interaction.timestamp,
                          _sid: nextSid)
        return event
    }
    
    func windowEvent(href: String, originalSize: CGSize, timestamp: TimeInterval) -> Event {
        let eventData = WindowData(href: href, size: paddedSize(originalSize))
        let event = Event(type: .Meta,
                          data: AnyEventData(eventData),
                          timestamp: timestamp,
                          _sid: nextSid)
        return event
    }
    
    func reloadEvent(timestamp: TimeInterval) -> Event {
        let eventData = CustomEventData(tag: .reload, payload: title)
        let event = Event(type: .Custom,
                          data: AnyEventData(eventData),
                          timestamp: timestamp,
                          _sid: nextSid)
        return event
    }
    
    func identifyEvent(itemPayload: IdentifyItemPayload) -> Event? {
        // Encode attributes as a JSON string for the `user` field.
        guard let data = try? JSONEncoder().encode(itemPayload.attributes),
              let userJSONString = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        let eventData = CustomEventData(tag: .identify, payload: userJSONString)
        let event = Event(type: .Custom,
                          data: AnyEventData(eventData),
                          timestamp: itemPayload.timestamp,
                          _sid: nextSid)
        return event
    }
    
    func viewPortEvent(exportFrame: ExportFrame, timestamp: TimeInterval) -> Event {
        let payload = ViewportPayload(width: Int(exportFrame.originalSize.width),
                                      height: Int(exportFrame.originalSize.height),
                                      availWidth: Int(exportFrame.originalSize.width),
                                      availHeight: Int(exportFrame.originalSize.height),
                                      colorDepth: 30,
                                      pixelDepth: 30,
                                      orientation: exportFrame.orientation)
        let eventData = CustomEventData(tag: .viewport, payload: payload)
        let event = Event(type: .Custom,
                          data: AnyEventData(eventData),
                          timestamp: timestamp,
                          _sid: nextSid)
        return event
    }
    
    private func tileNode(exportFrame: ExportFrame, image: ExportFrame.AddImage) -> (node: EventNode, canvasSize: Int) {
        let tileCanvasId = nextId
        if let tileSignature = image.tileSignature {
            nodeIds[tileSignature] = tileCanvasId
        }
        let base64DataURL = image.base64DataURL(mimeType: exportFrame.mimeType)
        return (image.tileEventNode(id: tileCanvasId, rr_dataURL: base64DataURL), base64DataURL.count)
    }
    
    private func addCommandNodes(exportFrame: ExportFrame, timestamp: TimeInterval, bodyId: Int) -> [Event] {
        var totalCanvasSize = 0
        if exportFrame.isKeyframe {
            nodeIds.removeAll()
        }
        if !exportFrame.isKeyframe, exportFrame.keyFrameId != knownKeyFrameId {
            // drop frame, we can reconstruct whole image only from known key frame
            return []
        }
        
        let adds: [AddedNode] = exportFrame.addImages.map { image in
            let (node, canvasSize) = tileNode(exportFrame: exportFrame, image: image)
            totalCanvasSize += canvasSize
            return AddedNode(parentId: bodyId, nextId: nil, node: node)
        }
        
        let removes: [RemovedNode] = exportFrame.removeImages?.compactMap { removal in
            guard let nodeId = nodeIds[removal.tileSignature] else {
                return nil
            }
            
            return RemovedNode(parentId: bodyId, id: nodeId)
        } ?? []
        
        if exportFrame.isKeyframe, let firstId = adds.first?.node.id, firstId != imageId {
            // Keyframe replacement can remove the previously tracked node.
            imageId = firstId
        }
    
        let mutationData = MutationData(adds: adds, removes: removes, canvasSize: totalCanvasSize)
        let mutationEvent = Event(type: .IncrementalSnapshot,
                                  data: AnyEventData(mutationData),
                                  timestamp: timestamp,
                                  _sid: nextSid)
        
        generatingCanvasSize += mutationData.canvasSize + RRWebPlayerConstants.canvasDrawEntourage
        return [mutationEvent]
    }
    
    func mouseEvent(timestamp: TimeInterval, x: CGFloat, y: CGFloat, timeOffset: TimeInterval) -> Event? {
        guard let imageId else { return nil }
        
        let eventData = MouseMoveEventData(source: .mouseMove, positions: [.init(x: x, y: y, id: imageId, timeOffset: timeOffset)])
        let event = Event(type: .IncrementalSnapshot,
                          data: AnyEventData(eventData),
                          timestamp: timestamp,
                          _sid: nextSid)
        return event
    }
    
    func fullSnapshotEvent(exportFrame: ExportFrame, timestamp: TimeInterval) -> Event {
        id = 0
        let eventData = fullSnapshotData(exportFrame: exportFrame)
        let event = Event(type: .FullSnapshot, data: AnyEventData(eventData), timestamp: timestamp, _sid: nextSid)
        // start again counting canvasSize
        generatingCanvasSize = eventData.canvasSize + RRWebPlayerConstants.canvasDrawEntourage
        return event
    }
    
    func fullSnapshotData(exportFrame: ExportFrame) -> DomData {        
        var rootNode = EventNode(id: nextId, type: .Document)
        var totalCanvasSize = 0
        let headNode = EventNode(id: nextId, type: .Element, tagName: Dom.head, attributes: [:])
        let currentBodyId = nextId
        let tileNodes = exportFrame.addImages.map { image in
            let (node, canvasSize) = tileNode(exportFrame: exportFrame, image: image)
            totalCanvasSize += canvasSize
            return node
        }
        let bodyNode = EventNode(id: currentBodyId, type: .Element, tagName: Dom.body,
                                 attributes: [Dom.style: Dom.bodyStyle],
                                 childNodes: tileNodes)
        let htmlNode = EventNode(id: nextId, type: .Element, tagName: Dom.html,
                                 attributes: [Dom.lang: Dom.en],
                                 childNodes: [headNode, bodyNode])
        imageId = tileNodes.first?.id
        bodyId = currentBodyId
        rootNode.childNodes.append(htmlNode)
        
        return DomData(node: rootNode, canvasSize: totalCanvasSize)
    }
    
    private func appendFullSnapshotEvents(_ exportFrame: ExportFrame, _ timestamp: TimeInterval, _ events: inout [Event]) {
        events.append(windowEvent(href: "", originalSize: exportFrame.originalSize, timestamp: timestamp))
        events.append(fullSnapshotEvent(exportFrame: exportFrame, timestamp: timestamp))
        events.append(viewPortEvent(exportFrame: exportFrame, timestamp: timestamp))
    }
    
    func updatePushedCanvasSize() {
        pushedCanvasSize = generatingCanvasSize
    }
}
