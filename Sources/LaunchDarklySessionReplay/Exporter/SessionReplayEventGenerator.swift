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

actor SessionReplayEventGenerator {
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
    private var lastImageWidth: Int = -1
    private var lastImageHeight: Int = -1
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
            let exportImage = payload.exportImage
            defer {
                lastImageWidth = exportImage.originalWidth
                lastImageHeight = exportImage.originalHeight
            }
            
            stats?.addExportImage(exportImage)
            
            let timestamp = item.timestamp
            
            if let imageId,
               lastImageWidth == exportImage.originalWidth,
               lastImageHeight == exportImage.originalHeight,
               generatingCanvasSize < RRWebPlayerConstants.canvasBufferLimit {
                events.append(drawImageEvent(exportImage: exportImage, timestamp: timestamp, imageId: imageId))
            } else {
                // if screen changed size we send fullSnapshot as canvas resizing might take to many hours on the server
                appendFullSnapshotEvents(exportImage, timestamp, &events)
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
    
    func viewPortEvent(exportImage: ExportImage, timestamp: TimeInterval) -> Event {
        let payload = ViewportPayload(width: Int(exportImage.originalSize.width),
                                      height: Int(exportImage.originalSize.height),
                                      availWidth: Int(exportImage.originalSize.width),
                                      availHeight: Int(exportImage.originalSize.height),
                                      colorDepth: 30,
                                      pixelDepth: 30,
                                      orientation: exportImage.orientation)
        let eventData = CustomEventData(tag: .viewport, payload: payload)
        let event = Event(type: .Custom,
                          data: AnyEventData(eventData),
                          timestamp: timestamp,
                          _sid: nextSid)
        return event
    }
    
    func drawImageEvent(exportImage: ExportImage, timestamp: TimeInterval, imageId: Int) -> Event {
        let clearRectCommand = ClearRect(rect: exportImage.rect)
        let base64String = exportImage.data.base64EncodedString()
        let arrayBuffer = RRArrayBuffer(base64: base64String)
        let blob = AnyRRNode(RRBlob(data: [AnyRRNode(arrayBuffer)], type: exportImage.mimeType))
        let drawImageCommand = DrawImage(image: AnyRRNode(RRImageBitmap(args: [blob])),
                                         rect: exportImage.rect)
        
        let eventData = CanvasDrawData(source: .canvasMutation,
                                       id: imageId,
                                       type: .mouseUp,
                                       commands: [
                                        AnyCommand(clearRectCommand, canvasSize: 80),
                                        AnyCommand(drawImageCommand, canvasSize: base64String.count)
                                       ])
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
    
    func fullSnapshotEvent(exportImage: ExportImage, timestamp: TimeInterval) -> Event {
        id = 0
        let eventData = fullSnapshotData(exportImage: exportImage)
        let event = Event(type: .FullSnapshot, data: AnyEventData(eventData), timestamp: timestamp, _sid: nextSid)
        // start again counting canvasSize
        generatingCanvasSize = eventData.canvasSize + RRWebPlayerConstants.canvasDrawEntourage
        return event
    }
    
    func fullSnapshotData(exportImage: ExportImage) -> DomData {
        var rootNode = EventNode(id: nextId, type: .Document)
        let htmlDocNode = EventNode(id: nextId, type: .DocumentType, name: "html")
        rootNode.childNodes.append(htmlDocNode)
        let base64String = exportImage.base64DataURL()

        let htmlNode = EventNode(id: nextId, type: .Element, tagName: "html", attributes: ["lang": "en"], childNodes: [
            EventNode(id: nextId, type: .Element, tagName: "head", attributes: [:]),
            EventNode(id: nextId, type: .Element, tagName: "body", attributes: [:], childNodes: [
                exportImage.eventNode(id: nextId, rr_dataURL: base64String)
            ]),
        ])
        imageId = id
        rootNode.childNodes.append(htmlNode)
        
        return DomData(node: rootNode, canvasSize: base64String.count)
    }
    
    private func appendFullSnapshotEvents(_ exportImage: ExportImage, _ timestamp: TimeInterval, _ events: inout [Event]) {
        events.append(windowEvent(href: "", originalSize: exportImage.originalSize, timestamp: timestamp))
        events.append(fullSnapshotEvent(exportImage: exportImage, timestamp: timestamp))
        events.append(viewPortEvent(exportImage: exportImage, timestamp: timestamp))
    }
    
    func updatePushedCanvasSize() {
        pushedCanvasSize = generatingCanvasSize
    }
}
