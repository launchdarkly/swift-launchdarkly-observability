import Foundation
#if canImport(UIKit)
import UIKit
#endif
import LaunchDarklyObservability
import OSLog
#if !LD_COCOAPODS
    import Common
#endif

actor SessionReplayEventGenerator {
    private var title: String
    let padding = CGSize(width: 11, height: 11)
    var sid = 0
    var nextSid: Int {
        sid += 1
        return sid
    }
    
    var id = 16
    var nextId: Int {
        id += 1
        return id
    }
    
    var imageId: Int?
    var lastExportImage: ExportImage?
    var stats: SessionReplayStats?
    let isDebug = false
    
    init(log: OSLog, title: String) {
        if isDebug {
            self.stats = SessionReplayStats(log: log)
        }
        self.title = title
    }
    
    func generateEvents(items: [EventQueueItem]) -> [Event] {
        var events = [Event]()
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
                            data: AnyEventData(EventData(source: .mouseInteraction,
                                                         type: .mouseDown,
                                                         id: imageId,
                                                         x: padding.width,
                                                         y: padding.height)),
                            timestamp: timestamp,
                            _sid: nextSid))
        events.append(Event(type: .IncrementalSnapshot,
                            data: AnyEventData(EventData(source: .mouseInteraction,
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
            guard lastExportImage != exportImage else {
                break
            }
            defer {
                lastExportImage = exportImage
            }
            
            stats?.addExportImage(exportImage)
            
            let timestamp = item.timestamp
            
            if let imageId,
               let lastExportImage,
               lastExportImage.originalWidth == exportImage.originalWidth,
               lastExportImage.originalHeight == exportImage.originalHeight {
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
    
    func paddedWidth(_ width: Int) -> Int {
        width + Int(padding.width) * 2
    }
    
    func paddedHeight(_ height: Int) -> Int {
        height + Int(padding.height) * 2
    }
    
    fileprivate func appendTouchInteraction(interaction: TouchInteraction, events: inout [Event]) {
        if let touchEventData: EventDataProtocol = switch interaction.kind {
        case .touchDown(let point):
            EventData(source: .mouseInteraction,
                      type: .touchStart,
                      id: imageId,
                      x: point.x + padding.width,
                      y: point.y + padding.height)
            
        case .touchUp(let point):
            EventData(source: .mouseInteraction,
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
            Optional<EventData>.none
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
        
        let viewName = interaction.target?.className
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
    

    
    func windowEvent(href: String, width: Int, height: Int, timestamp: TimeInterval) -> Event {
        let eventData = EventData(href: href, width: width, height: height)
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
        let payload = ViewportPayload(width: exportImage.originalWidth,
                                      height: exportImage.originalHeight,
                                      availWidth: exportImage.originalWidth,
                                      availHeight: exportImage.originalHeight,
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
        let clearRectCommand = ClearRect(x: 0, y: 0, width: exportImage.originalWidth, height: exportImage.originalHeight)
        let arrayBuffer = RRArrayBuffer(base64: exportImage.data.base64EncodedString())
        let blob = AnyRRNode(RRBlob(data: [AnyRRNode(arrayBuffer)], type: exportImage.mimeType))
        let drawImageCommand = DrawImage(image: AnyRRNode(RRImageBitmap(args: [blob])),
                                         dx: 0,
                                         dy: 0,
                                         dw: exportImage.originalWidth,
                                         dh: exportImage.originalHeight)
        
        let eventData = CanvasDrawData(source: .canvasMutation,
                                       id: imageId,
                                       type: .mouseUp,
                                       commands: [
                                        AnyCommand(clearRectCommand),
                                        AnyCommand(drawImageCommand)
                                       ])
        let event = Event(type: .IncrementalSnapshot, data: AnyEventData(eventData), timestamp: timestamp, _sid: nextSid)
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
        let rootNode = fullSnapshotNode(exportImage: exportImage)
        let eventData = EventData(node: rootNode)
        let event = Event(type: .FullSnapshot, data: AnyEventData(eventData), timestamp: timestamp, _sid: nextSid)
        return event
    }
    
    func fullSnapshotNode(exportImage: ExportImage) -> EventNode {
        var rootNode = EventNode(id: nextId, type: .Document)
        let htmlDocNode = EventNode(id: nextId, type: .DocumentType, name: "html")
        rootNode.childNodes.append(htmlDocNode)
        
        let htmlNode = EventNode(id: nextId, type: .Element, tagName: "html", attributes: ["lang": "en"], childNodes: [
            EventNode(id: nextId, type: .Element, tagName: "head", attributes: [:]),
            EventNode(id: nextId, type: .Element, tagName: "body", attributes: [:], childNodes: [
                exportImage.eventNode(id: nextId)
            ]),
        ])
        imageId = id
        rootNode.childNodes.append(htmlNode)
        
        return rootNode
    }
    
    private func appendFullSnapshotEvents(_ exportImage: ExportImage, _ timestamp: TimeInterval, _ events: inout [Event]) {
        events.append(windowEvent(href: "", width: paddedWidth(exportImage.originalWidth), height: paddedHeight(exportImage.originalHeight), timestamp: timestamp))
        events.append(fullSnapshotEvent(exportImage: exportImage, timestamp: timestamp))
        events.append(viewPortEvent(exportImage: exportImage, timestamp: timestamp))
    }
}
