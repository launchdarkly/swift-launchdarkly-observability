import Foundation
import Common

enum ScreenshotServiceError: Error {
    case loadingJSONFailed(String)
    case networkError(Error)
    case decodingError(Error?)
}

actor ScreenshotService {
    let replayApiService: SessionReplayAPIService
    
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
    
    var imageId: Int = 16
    
    var currentSession: InitializeSessionResponse?
    var lastExporImage: ExportImage?
    
    init(replayApiService: SessionReplayAPIService) {
        self.replayApiService = replayApiService
    }
    
    var notScreenItems = [EventQueueItem]()
    
    func send(items: [EventQueueItem]) async throws {
        if currentSession == nil {
            let session = try await initializeSession(sessionSecureId: ReplaySessionGenerator.generateSecureID())
            try await identifySession(session: session)
            currentSession = session
        }
        
        guard let currentSession else {
            return
        }
        
        var events = [Event]()
        for item in items {
            appendEvents(item: item, events: &events)
        }
        
        if events.isNotEmpty {
            try await pushPayload(events: events)
        }
        
        try await pushNotScreenshotItems(items: notScreenItems)
    }
    
    func oldSend(items: [EventQueueItem]) async throws {
        
    }
    
    func appendEvents(item: EventQueueItem, events: inout [Event]) -> Event? {
        switch item.payload {
        case .screenshot(let exportImage):
            guard lastExporImage != exportImage else {
                return nil
            }
            lastExporImage = exportImage
            let timestamp = item.timestamp
            
            if payloadId <= 1 {
                fullSnapshotEvent(exportImage, timestamp, &events)
                
                //try await pushNotScreenshotItems(items: notScreenItems)
                //try await pushPayloadFullSnapshot(session: currentSession, exportImage: exportImage, timestamp: timestamp)
                // fake mouse movement to trigger something
                //try await pushPayload(session: currentSession, resource: "payload2", timestamp: timestamp)
            } else {
                try await pushNotScreenshotItems(items: notScreenItems)
                try await pushPayloadDrawImage(session: currentSession, timestamp: timestamp, exportImage: exportImage)
            }
        case .tap(let toucEvent):
            notScreenItems.append(item)
        }
    }
    
    func tapEvent(touch: TouchEvent, timestamp: Int64) -> Event? {
        var type: MouseInteractions?
        switch touch.phase {
        case .began:
            type = .click
        case .ended:
            type = .touchEnd
        @unknown default:
            () // NO-OP
        }
        guard let type else {
            return nil
        }
        
        let eventData = EventData(source: .mouseInteraction,
                                  type: type,
                                  id: imageId,
                                  x: touch.location.x,
                                  y: touch.location.y)
        let event = Event(type: .IncrementalSnapshot,
                          data: AnyEventData(eventData),
                          timestamp: timestamp,
                          _sid: nextSid)
        return event
    }
    
    func pushNotScreenshotItems(items: [EventQueueItem]) async throws {
        guard let currentSession else {
            return
        }
        guard items.isNotEmpty else { return }
        
        var events = [Event]()
        for item in items {
            switch item.payload {
            case .screenshot:
                continue
                
            case .tap(let touch):
                if let tapEvent = tapEvent(touch: touch, timestamp: item.timestamp) {
                    events.append(tapEvent)
                }
            }
        }
        
        if events.isNotEmpty {
            let input = PushPayloadVariables(sessionSecureId: currentSession.secureId, payloadId: "\(nextPayloadId)", events: events)
            try await replayApiService.pushPayload(input)
        }
 
        notScreenItems.removeAll()
    }
    
    func initializeSession(sessionSecureId: String) async throws -> InitializeSessionResponse {
        try await replayApiService.initializeSession(sessionSecureId: sessionSecureId)
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
    
    func prepareImageNode(imageNode: EventNode? = nil) -> EventNode? {
        guard var imageNode else { return nil }
        imageNode.id = nextId
        imageNode.rootId = 1
        return imageNode
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
        let eventData = CustomEventData(tag: "Reload", payload: "iOS Demo")
        let event = Event(type: .Custom,
                          data: AnyEventData(eventData),
                          timestamp: timestamp,
                          _sid: nextSid)
        return event
    }
    
    func viewPortEvent(exportImage: ExportImage, timestamp: Int64) -> Event {
        let payload = ViewPortPayload(width: exportImage.originalWidth,
                                      height: exportImage.originalHeight,
                                      availWidth: exportImage.originalWidth,
                                      availHeight: exportImage.originalHeight,
                                      colorDepth: 30,
                                      pixelDepth: 30,
                                      orientation: 0)
        let eventData = CustomEventData(tag: "Viewport", payload: payload)
        let event = Event(type: .Custom,
                          data: AnyEventData(eventData),
                          timestamp: timestamp,
                          _sid: nextSid)
        return event
    }
    
    func drawImageEvent(exportImage: ExportImage, timestamp: Int64) -> Event {
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
    
    func fullSnapshotEvent(exportImage: ExportImage, timestamp: Int64) -> Event {
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
    
    fileprivate func fullSnapshotEvent(_ exportImage: ExportImage, _ timestamp: Int64, _ events: inout [Event]) {
        //let imageNode = exportImage.eventNode(id: 16)
        // event with window size
        events.append(windowEvent(href: "http://localhost:5173/", width: exportImage.paddedWidth, height: exportImage.paddedHeight, timestamp: timestamp))
        events.append(fullSnapshotEvent(exportImage: exportImage, timestamp: timestamp))
        events.append(reloadEvent(timestamp: timestamp))
        events.append(viewPortEvent(exportImage: exportImage, timestamp: timestamp))
    }
    
    func pushPayloadFullSnapshot(session: InitializeSessionResponse, exportImage: ExportImage? = nil, timestamp: Int64) async throws {
        var events = [Event]()
        guard let exportImage else {
            return
        }
        
        fullSnapshotEvent(exportImage, timestamp, &events)
        
        let input = PushPayloadVariables(sessionSecureId: session.secureId, payloadId: "\(nextPayloadId)", events: events)
        try await replayApiService.pushPayload(input)
    }
    

    func pushPayloadDrawImage(session: InitializeSessionResponse, timestamp: Int64, exportImage: ExportImage) async throws {
        let event = drawImageEvent(exportImage: exportImage, timestamp: timestamp)
        let input = PushPayloadVariables(sessionSecureId: session.secureId, payloadId: "\(nextPayloadId)", events: [event])
        try await replayApiService.pushPayload(input)
    }
    
 
}
