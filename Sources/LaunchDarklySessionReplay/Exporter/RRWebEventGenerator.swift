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
    static let canvasBufferLimit = 10_000_000 // ~10mb
    
    static let canvasDrawEntourage = 300 // bytes
}

actor RRWebEventGenerator {
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
    private var lastImageSize: CGSize?
    private var stats: SessionReplayStats?
    private let isDebug = false
    
    init(log: OSLog, title: String) {
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

//            if let bodyId,
//               lastImageSize == exportFrame.originalSize,
//               generatingCanvasSize < RRWebPlayerConstants.canvasBufferLimit  {
//                events.append(contentsOf: addTileNodes(exportFrame: exportFrame, timestamp: timestamp, bodyId: bodyId))
//            } else {
//                // if screen changed size we send fullSnapshot as canvas resizing might take to many hours on the server
//                appendFullSnapshotEvents(exportFrame, timestamp, &events)
//            }
//            
            if let bodyId, let imageId,
               lastImageSize == exportFrame.originalSize,
               generatingCanvasSize < RRWebPlayerConstants.canvasBufferLimit  {
                if !exportFrame.isKeyframe {
                    events.append(contentsOf: addTileNodes(exportFrame: exportFrame, timestamp: timestamp, bodyId: bodyId))
                } else {
                    events.append(contentsOf: addTileNodes(exportFrame: exportFrame, timestamp: timestamp, bodyId: bodyId))
                   // events.append(drawImageEvent(exportFrame: exportFrame, timestamp: timestamp, imageId: imageId))
                }
            } else {
                // if screen changed size we send fullSnapshot as canvas resizing might take to many hours on the server
                appendFullSnapshotEvents(exportFrame, timestamp, &events)
            }
//            
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
    
    /// Generates a DOM mutation event to add tile canvases on top of the main canvas.
    /// Each tile canvas uses rr_dataURL to pre-render the image, no separate draw command needed.
    func addTileNodes(exportFrame: ExportFrame, timestamp: TimeInterval, bodyId: Int) -> [Event] {
        var adds = [AddedNode]()
        var totalCanvasSize = 0
        
        for image in exportFrame.images {
            let tileCanvasId = nextId
            let base64DataURL = image.base64DataURL(mimeType: exportFrame.mimeType)
            let tileNode = image.tileEventNode(id: tileCanvasId, rr_dataURL: base64DataURL)
            adds.append(AddedNode(parentId: bodyId, nextId: nil, node: tileNode))
            totalCanvasSize += base64DataURL.count
        }
        
        let mutationData = MutationData(adds: adds, canvasSize: totalCanvasSize)
        let mutationEvent = Event(type: .IncrementalSnapshot,
                                   data: AnyEventData(mutationData),
                                   timestamp: timestamp,
                                   _sid: nextSid)
        
        generatingCanvasSize += mutationData.canvasSize + RRWebPlayerConstants.canvasDrawEntourage
        return [mutationEvent]
    }
    
    func drawImageEvent(exportFrame: ExportFrame, timestamp: TimeInterval, imageId: Int) -> Event {
        var commands = [AnyCommand]()
        for image in exportFrame.images {
            if exportFrame.isKeyframe {
                let clearRectCommand = ClearRect(rect: image.rect)
                commands.append(AnyCommand(clearRectCommand, canvasSize: 80))
            }
            let base64String = image.data.base64EncodedString()
            let arrayBuffer = RRArrayBuffer(base64: base64String)
            let blob = AnyRRNode(RRBlob(data: [AnyRRNode(arrayBuffer)], type: exportFrame.mimeType))
            let drawImageCommand = DrawImage(image: AnyRRNode(RRImageBitmap(args: [blob])),
                                             rect: image.rect)
            commands.append(AnyCommand(drawImageCommand, canvasSize: base64String.count))
        }
        let eventData = CanvasDrawData(source: .canvasMutation,
                                       id: imageId,
                                       type: .mouseUp,
                                       commands: commands)
        let event = Event(type: .IncrementalSnapshot,
                          data: AnyEventData(eventData),
                          timestamp: timestamp, _sid: nextSid)
        generatingCanvasSize += eventData.canvasSize + RRWebPlayerConstants.canvasDrawEntourage
        return event
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
        let htmlDocNode = EventNode(id: nextId, type: .DocumentType, name: "html")
        rootNode.childNodes.append(htmlDocNode)
        let firstImage = exportFrame.images[0]
        let base64String = firstImage.base64DataURL(mimeType: exportFrame.mimeType)

        let headNode = EventNode(id: nextId, type: .Element, tagName: "head", attributes: [:])
        let currentBodyId = nextId
        let bodyNode = EventNode(id: currentBodyId, type: .Element, tagName: "body",
                                  attributes: ["style": "position:relative;"],
                                  childNodes: [
                                      exportFrame.eventNode(id: nextId, rr_dataURL: base64String)
                                  ])
        let htmlNode = EventNode(id: nextId, type: .Element, tagName: "html",
                                  attributes: ["lang": "en"],
                                  childNodes: [headNode, bodyNode])
        imageId = id
        bodyId = currentBodyId
        rootNode.childNodes.append(htmlNode)
        
        return DomData(node: rootNode, canvasSize: base64String.count)
    }
    
    private func appendFullSnapshotEvents(_ exportFrame: ExportFrame, _ timestamp: TimeInterval, _ events: inout [Event]) {
        events.append(windowEvent(href: "", originalSize: exportFrame.originalSize, timestamp: timestamp))
        events.append(fullSnapshotEvent(exportFrame: exportFrame, timestamp: timestamp))
        events.append(viewPortEvent(exportFrame: exportFrame, timestamp: timestamp))
    }
    
    private func appendKeyFrameEvents(_ exportFrame: ExportFrame, _ timestamp: TimeInterval, _ events: inout [Event]) {
    }
    
    func updatePushedCanvasSize() {
        pushedCanvasSize = generatingCanvasSize
    }
}
