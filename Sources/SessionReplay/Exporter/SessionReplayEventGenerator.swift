import Foundation
#if canImport(UIKit)
import UIKit
#endif
import Common
import Observability

actor SessionReplayEventGenerator {    
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
    var shouldMoveMouseOnce = true
    var imageId: Int?
    var lastExportImage: ExportImage?
    let positionCorrection = ExportImage.padding
    
    init() {
    }
    
    func generateEvents(items: [EventQueueItem]) -> [Event] {
        var events = [Event]()
        for item in items {
            appendEvents(item: item, events: &events)
        }
        return events
    }
    
    func appendEvents(item: EventQueueItem, events: inout [Event]) {
        switch item.payload {
        case let payload as ScreenImageItem:
            let exportImage = payload.exportImage
            guard lastExportImage != exportImage else {
                return
            }
            defer {
                lastExportImage = exportImage
            }
            let timestamp = item.timestamp
        
            if let imageId, shouldMoveMouseOnce {
                events.append(reloadEvent(timestamp: timestamp))
                // artificial mouse movement to wake up session replay player
                let event = Event(type: .IncrementalSnapshot,
                                  data: AnyEventData(EventData(source: .mouseInteraction,
                                                               type: .touchStart,
                                                               id: imageId,
                                                               x: positionCorrection.x,
                                                               y: positionCorrection.y)),
                                  timestamp: timestamp,
                                  _sid: nextSid)
                events.append(event)
                shouldMoveMouseOnce = false
            }
            
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
        default:
            () //
        }
    }
    
    fileprivate func appendTouchInteraction(interaction: TouchInteraction, events: inout [Event]) {
        if let touchEventData: EventDataProtocol = switch interaction.kind {
        case .touchDown(let point):
            EventData(source: .mouseInteraction,
                      type: .touchStart,
                      id: imageId,
                      x: point.x + positionCorrection.x,
                      y: point.y + positionCorrection.y)
            
        case .touchUp(let point):
            EventData(source: .mouseInteraction,
                      type: .touchEnd,
                      id: imageId,
                      x: point.x + positionCorrection.x,
                      y: point.y + positionCorrection.y)
            
        case .touchPath(let points):
            MouseMoveEventData(
                source: .touchMove,
                positions: points.map { p in MouseMoveEventData.Position(
                    x: p.position.x + positionCorrection.x,
                    y: p.position.y + positionCorrection.y,
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
        let eventData = CustomEventData(tag: .reload, payload: "iOS Demo")
        let event = Event(type: .Custom,
                          data: AnyEventData(eventData),
                          timestamp: timestamp,
                          _sid: nextSid)
        return event
    }
    
    func viewPortEvent(exportImage: ExportImage, timestamp: TimeInterval) -> Event {
        #if os(iOS)
        let currentOrientation = UIDevice.current.orientation.isLandscape ? 1 : 0
        #else
        let currentOrientation = 0
        #endif
        let payload = ViewportPayload(width: exportImage.originalWidth,
                                      height: exportImage.originalHeight,
                                      availWidth: exportImage.originalWidth,
                                      availHeight: exportImage.originalHeight,
                                      colorDepth: 30,
                                      pixelDepth: 30,
                                      orientation: currentOrientation)
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
    
    func fullSnapshotEvent(exportImage: ExportImage, timestamp: TimeInterval, isEmpty: Bool) -> Event {
        id = 0
        let rootNode = fullSnapshotNode(exportImage: exportImage, emtpyCanvas: isEmpty)
        let eventData = EventData(node: rootNode)
        let event = Event(type: .FullSnapshot, data: AnyEventData(eventData), timestamp: timestamp, _sid: nextSid)
        return event
    }
    
    func fullSnapshotNode(exportImage: ExportImage, emtpyCanvas: Bool) -> EventNode {
        var rootNode = EventNode(id: nextId, type: .Document)
        let htmlDocNode = EventNode(id: nextId, type: .DocumentType, name: "html")
        rootNode.childNodes.append(htmlDocNode)
        
        let htmlNode = EventNode(id: nextId, type: .Element, tagName: "html", attributes: ["lang": "en"], childNodes: [
            EventNode(id: nextId, type: .Element, tagName: "head", attributes: [:]),
            EventNode(id: nextId, type: .Element, tagName: "body", attributes: [:], childNodes: [
                exportImage.eventNode(id: nextId, use_rr_dataURL: !emtpyCanvas)
            ]),
        ])
        imageId = id
        rootNode.childNodes.append(htmlNode)
        
        return rootNode
    }
    
    private func appendFullSnapshotEvents(_ exportImage: ExportImage, _ timestamp: TimeInterval, _ events: inout [Event]) {
        events.append(windowEvent(href: "", width: exportImage.paddedWidth, height: exportImage.paddedHeight, timestamp: timestamp))
        events.append(fullSnapshotEvent(exportImage: exportImage, timestamp: timestamp, isEmpty: false))
        
        // Workaround to solve session player flicker. TODO: optimize but not generating base64 twice in case it persists
        events.append(fullSnapshotEvent(exportImage: exportImage, timestamp: timestamp, isEmpty: true))
        if let imageId {
            events.append(drawImageEvent(exportImage: exportImage, timestamp: timestamp, imageId: imageId))
        }
        
        events.append(viewPortEvent(exportImage: exportImage, timestamp: timestamp))
    }
}

extension ScreenImageItem: SessionReplayItemPayload {
    func sessionReplayEvent() -> Event? {
        return nil
    }
}
