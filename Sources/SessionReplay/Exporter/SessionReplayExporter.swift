import Foundation
import Common
import Observability

actor SessionReplayExporter: EventExporting {
    let replayApiService: SessionReplayAPIService
    let context: SessionReplayContext
    let sessionService: SessionService

    var payloadId = 0
    var nextPayloadId: Int {
        payloadId += 1
        return payloadId
    }
    
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
    var currentSession: InitializeSessionResponse?
    var lastExportImage: ExportImage?
    var shouldReload = true
    
    init(context: SessionReplayContext, sessionService: SessionService, replayApiService: SessionReplayAPIService) {
        self.context = context
        self.replayApiService = replayApiService
        self.sessionService = sessionService
    }
    
    var notScreenItems = [EventQueueItem]()
    var fakePayloadOnce = false
    
    func export(items: [EventQueueItem]) async throws {
        if currentSession == nil {
            let session = try await initializeSession(sessionSecureId: sessionService.sessionInfo().id)
            try await identifySession(session: session)
            currentSession = session
        }
        
        var events = [Event]()
        for item in items {
            appendEvents(item: item, events: &events)
        }
        
        guard let firstEvent = events.first else { return }
        
        if let currentSession, !fakePayloadOnce {
            fakePayloadOnce = true
            try await pushPayload(session: currentSession, resource: "payload2", timestamp: firstEvent.timestamp)
        }
        try await pushPayload(events: events)
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
            
            if shouldReload {
                // TODO: make it through real event, when we subscribe device events
                events.append(reloadEvent(timestamp: timestamp))
                // fake movement
                if let mouseEvent = mouseEvent(timestamp: timestamp, x: 0, y: 0, timeOffset: 0) {
                    events.append(mouseEvent)
                }
                shouldReload = false
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
            
        case let touchEvent as TouchItemPayload:
            appendTouchEvents(touch: touchEvent.touchEvent, events: &events, timestamp: item.timestamp)
        default:
            () //
        }
    }
    
    fileprivate func addTouchInteraction(_ type: MouseInteractions, _ touch: TouchEvent, _ timestamp: Int64, _ events: inout [Event]) {
        let eventData = EventData(source: .mouseInteraction,
                                  type: type,
                                  id: imageId,
                                  x: touch.location.x,
                                  y: touch.location.y)
        let event = Event(type: .IncrementalSnapshot,
                          data: AnyEventData(eventData),
                          timestamp: timestamp,
                          _sid: nextSid)
        events.append(event)
    }
    
    func appendTouchEvents(touch: TouchEvent, events: inout [Event], timestamp: Int64) {
        var type: MouseInteractions?
        switch touch.phase {
        case .began:
            type = .touchStart
//            if let mouseEvent = mouseEvent(timestamp: timestamp,
//                                           x: touch.location.x,
//                                           y: touch.location.y,
//                                           timeOffset: 100) {
//                events.append(mouseEvent)
//            }
        case .ended:
            type = .touchEnd
            if let mouseEvent = mouseEvent(timestamp: timestamp,
                                           x: touch.location.x,
                                           y: touch.location.y,
                                           timeOffset: 900) {
                events.append(mouseEvent)
            }
            
        case .moved:
            () // NO-OP
        }
        guard let type else {
            return
        }
        
        addTouchInteraction(type, touch, timestamp, &events)
        
        if let clickEvent = clickEvent(touchEvent: touch, timestamp: timestamp) {
            events.append(clickEvent)
        }
    }
    
    func clickEvent(touchEvent: TouchEvent, timestamp: Int64) -> Event? {
        guard touchEvent.phase == .ended, let viewName = touchEvent.viewName else { return nil }
            
        let eventData = CustomEventData(tag: .click, payload: ClickPayload(
            clickTarget: viewName,
            clickTextContent: touchEvent.title ?? "",
            clickSelector: touchEvent.accessibilityIdentifier ?? "view"))
        let event = Event(type: .Custom,
                          data: AnyEventData(eventData),
                          timestamp: timestamp,
                          _sid: nextSid)
        return event
    }
    
    func pushPayload(events: [Event]) async throws {
        guard let currentSession else { return }
        guard events.isNotEmpty else { return }
        
        let input = PushPayloadVariables(sessionSecureId: currentSession.secureId, payloadId: "\(nextPayloadId)", events: events)
        try await replayApiService.pushPayload(input)
    }
    
    func initializeSession(sessionSecureId: String) async throws -> InitializeSessionResponse {
        try await replayApiService.initializeSession(context: context,
                                                     sessionSecureId: sessionSecureId,
                                                     userIdentifier: "abelonogov@launchdarkly.com")
    }
    
    func identifySession(session: InitializeSessionResponse) async throws {
        try await replayApiService.identifySession(
            sessionSecureId: session.secureId,
            userObject:   ["telemetry.sdk.name":"JSClient",
                           "telemetry.sdk.version":"3.8.1",
                           "feature_flag.set.id":"548f6741c1efad40031b18ae",
                           "feature_flag.provider.name":"LaunchDarkly",
                           "key":"unknown"])
    }
    
    func windowEvent(href: String, width: Int, height: Int, timestamp: Int64) -> Event {
        let eventData = EventData(href: href, width: width, height: height)
        let event = Event(type: .Meta,
                          data: AnyEventData(eventData),
                          timestamp: timestamp,
                          _sid: nextSid)
        return event
    }
    
    func reloadEvent(timestamp: Int64) -> Event {
        let eventData = CustomEventData(tag: .reload, payload: "iOS Demo")
        let event = Event(type: .Custom,
                          data: AnyEventData(eventData),
                          timestamp: timestamp,
                          _sid: nextSid)
        return event
    }
    
    func viewPortEvent(exportImage: ExportImage, timestamp: Int64) -> Event {
        let payload = ViewportPayload(width: exportImage.originalWidth,
                                      height: exportImage.originalHeight,
                                      availWidth: exportImage.originalWidth,
                                      availHeight: exportImage.originalHeight,
                                      colorDepth: 30,
                                      pixelDepth: 30,
                                      orientation: Int.random(in: 0...1))
        let eventData = CustomEventData(tag: .viewport, payload: payload)
        let event = Event(type: .Custom,
                          data: AnyEventData(eventData),
                          timestamp: timestamp,
                          _sid: nextSid)
        return event
    }
    
    func drawImageEvent(exportImage: ExportImage, timestamp: Int64, imageId: Int) -> Event {
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
    
    func mouseEvent(timestamp: Int64, x: CGFloat, y: CGFloat, timeOffset: Int64) -> Event? {
        guard let imageId else { return nil }
       
        let x = Int(x), y = Int(y)
        let eventData = MouseMoveEventData(source: .mouseMove, positions: [.init(x: x, y: y, id: "\(imageId)", timeOffset: timeOffset)])
        let event = Event(type: .IncrementalSnapshot,
                          data: AnyEventData(eventData),
                          timestamp: timestamp,
                          _sid: nextSid)
        return event
    }
    
    func fullSnapshotEvent(exportImage: ExportImage, timestamp: Int64, isEmpty: Bool) -> Event {
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
    
    private func appendFullSnapshotEvents(_ exportImage: ExportImage, _ timestamp: Int64, _ events: inout [Event]) {
        events.append(windowEvent(href: "", width: exportImage.paddedWidth, height: exportImage.paddedHeight, timestamp: timestamp))
        events.append(fullSnapshotEvent(exportImage: exportImage, timestamp: timestamp, isEmpty: false))
       
        // Workaround to solve session player flicker. TODO: optimize but not generating base64 twice in case it persists
        events.append(fullSnapshotEvent(exportImage: exportImage, timestamp: timestamp, isEmpty: true))
        if let imageId {
            events.append(drawImageEvent(exportImage: exportImage, timestamp: timestamp, imageId: imageId))
        }
        
        events.append(viewPortEvent(exportImage: exportImage, timestamp: timestamp))
    }
    
    func pushPayloadFullSnapshot(session: InitializeSessionResponse, exportImage: ExportImage? = nil, timestamp: Int64) async throws {
        var events = [Event]()
        guard let exportImage else {
            return
        }
        
        appendFullSnapshotEvents(exportImage, timestamp, &events)
        
        let input = PushPayloadVariables(sessionSecureId: session.secureId, payloadId: "\(nextPayloadId)", events: events)
        try await replayApiService.pushPayload(input)
    }
    
    func pushPayloadDrawImage(session: InitializeSessionResponse, timestamp: Int64, exportImage: ExportImage, imageId: Int) async throws {
        let event = drawImageEvent(exportImage: exportImage, timestamp: timestamp, imageId: imageId)
        let input = PushPayloadVariables(sessionSecureId: session.secureId, payloadId: "\(nextPayloadId)", events: [event])
        try await replayApiService.pushPayload(input)
    }
}

extension ScreenImageItem: SessionReplayItemPayload {
    func sessionReplayEvent() -> Event? {
        return nil
    }
}
