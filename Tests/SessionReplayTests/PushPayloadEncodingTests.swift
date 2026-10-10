import Testing
import Foundation
import OSLog
import CoreGraphics
import Common
@testable import LaunchDarklySessionReplay
@testable import LaunchDarklyObservability

/// Pins the streaming encoder to `JSONEncoder`.
///
/// The replay wire types carry both: `Codable`, and a `JSONStreamWritable` conformance that writes the same JSON
/// without boxing the payload first. These tests are what keeps the two from drifting, so a type that gains a field
/// has to gain it in both places.
struct PushPayloadEncodingTests {
    // MARK: Parity

    @Test("Every generated event writes what JSONEncoder would have encoded")
    func eventsMatchJSONEncoder() async throws {
        for event in try await makeEventsCoveringEveryKind() {
            #expect(try jsonObject(streaming: event) == jsonObject(encoding: event))
        }
    }

    @Test("The push payload body matches what GraphQLRequest would have sent")
    func pushPayloadBodyMatchesGraphQLRequest() async throws {
        let variables = PushPayloadVariables(sessionSecureId: "session-1",
                                             payloadId: "7",
                                             events: try await makeEventsCoveringEveryKind())

        let body = SessionReplayAPIService.pushPayloadBody(variables)
        let written = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        // The query is the encoder's own, so it is fed back through `GraphQLRequest` rather than restated here.
        let query = try #require(written["query"] as? String)
        let expected = try GraphQLRequest(query: query,
                                          variables: variables,
                                          operationName: written["operationName"] as? String).httpBody()

        #expect(query.contains("mutation PushPayload"))
        #expect(written["operationName"] as? String == "PushPayload")
        #expect(NSDictionary(dictionary: written) == (try JSONSerialization.jsonObject(with: expected) as? NSDictionary))
    }

    @Test("Optional variables are omitted when unset and written when set")
    func optionalVariablesMatchJSONEncoder() async throws {
        let events = [Event(type: .Custom,
                            data: AnyEventData(CustomEventData(tag: .navigate, payload: "Profile")),
                            timestamp: 1.0,
                            _sid: 1)]

        for (isBeacon, hasUnloaded, logs) in [(nil, nil, nil), (true, false, "log line")] as [(Bool?, Bool?, String?)] {
            let variables = PushPayloadVariables(sessionSecureId: "session-1",
                                                 payloadId: "1",
                                                 events: events,
                                                 isBeacon: isBeacon,
                                                 hasSessionUnloaded: hasUnloaded,
                                                 highlightLogs: logs)

            #expect(try jsonObject(streaming: variables) == jsonObject(encoding: variables))
        }
    }

    // MARK: Images

    @Test("A tile's src is the data URL of its bytes, encoded straight into the payload")
    func tileSourceIsTheDataURLOfItsBytes() async throws {
        let imageData = Data((0..<1024).map { UInt8($0 % 256) })
        let events = await makeGenerator().generateEvents(items: [imageItem(data: imageData, timestamp: 1.0)])

        let snapshot = try #require(events.first { $0.type == .FullSnapshot })
        let source = try #require(firstImageSource(in: jsonObject(streaming: snapshot)))

        #expect(source == "data:image/png;base64,\(imageData.base64EncodedString())")
    }

    @Test("A tile's canvas-budget size is the length of the data URL it will be written as")
    func tileCanvasSizeMatchesTheWrittenLength() {
        let image = ExportFrame.AddImage(data: Data((0..<1001).map { UInt8($0 % 256) }),
                                         rect: CGRect(x: 0, y: 0, width: 10, height: 10),
                                         imageSignature: nil)
        let dataURL = NodeAttributeValue.imageDataURL(mimeType: "image/jpeg", data: image.data).stringValue

        #expect(image.dataURLByteCount(mimeType: "image/jpeg") == dataURL.utf8.count)
    }

    @Test("The buffer is reserved from the image sizes already tracked for the canvas budget")
    func payloadReservesRoomForItsImages() async throws {
        let imageData = Data(count: 64 * 1024)
        let events = await makeGenerator().generateEvents(items: [imageItem(data: imageData, timestamp: 1.0)])
        let variables = PushPayloadVariables(sessionSecureId: "session-1", payloadId: "1", events: events)

        let body = SessionReplayAPIService.pushPayloadBody(variables)

        // Enough for the image, which is all of the payload that is worth reserving for, and not so much that the
        // buffer is sized from something other than the frames.
        #expect(variables.estimatedJSONByteCount >= imageData.base64EncodedString().utf8.count)
        #expect(variables.estimatedJSONByteCount <= body.count * 2)
    }

    // MARK: Helpers

    private func makeGenerator() -> RRWebEventGenerator {
        RRWebEventGenerator(log: OSLog(subsystem: "test", category: "test"), title: "Test", method: .overlayTiles())
    }

    private func imageItem(data: Data, timestamp: TimeInterval, keyFrameId: Int = 0, isKeyframe: Bool = true) -> EventQueueItem {
        let rect = CGRect(x: 0, y: 0, width: 320, height: 480)
        let frame = ExportFrame(keyFrameId: keyFrameId,
                                addImages: [ExportFrame.AddImage(data: data, rect: rect, imageSignature: nil)],
                                removeImages: nil,
                                originalSize: rect.size,
                                scale: 1.0,
                                format: .png,
                                timestamp: timestamp,
                                orientation: 0,
                                isKeyframe: isKeyframe,
                                imageSignature: nil)
        return EventQueueItem(payload: ImageItemPayload(exportFrame: frame, sessionId: "test-session"))
    }

    /// One of every event the SDK emits: the meta/full-snapshot/viewport trio, a tile mutation, the pointer events,
    /// and each custom breadcrumb.
    private func makeEventsCoveringEveryKind() async throws -> [Event] {
        let generator = makeGenerator()
        let items: [EventQueueItem] = [
            imageItem(data: Data((0..<512).map { UInt8($0 % 256) }), timestamp: 1.0),
            imageItem(data: Data((0..<256).map { UInt8(255 - $0 % 256) }), timestamp: 2.0, isKeyframe: false),
            EventQueueItem(payload: TouchInteraction(id: 1,
                                                     kind: .touchDown(CGPoint(x: 10, y: 20)),
                                                     startTimestamp: 3.0,
                                                     timestamp: 3.0,
                                                     target: nil,
                                                     sessionId: "test-session")),
            EventQueueItem(payload: TouchInteraction(id: 2,
                                                     kind: .touchPath(points: [TouchPoint(position: CGPoint(x: 11, y: 21), timestamp: 3.1),
                                                                               TouchPoint(position: CGPoint(x: 12.5, y: 22.5), timestamp: 3.2)]),
                                                     startTimestamp: 3.1,
                                                     timestamp: 3.1,
                                                     target: nil,
                                                     sessionId: "test-session")),
            EventQueueItem(payload: TouchInteraction(id: 3,
                                                     kind: .touchUp(CGPoint(x: 13, y: 23)),
                                                     startTimestamp: 3.3,
                                                     timestamp: 3.3,
                                                     target: nil,
                                                     sessionId: "test-session")),
            EventQueueItem(payload: PressInteractionPayload(pressInteraction: PressInteraction(phase: .began,
                                                                                               kind: .keyboard,
                                                                                               timestamp: 4.0,
                                                                                               target: nil,
                                                                                               sessionId: "test-session"))),
            EventQueueItem(payload: ClickItemPayload(click: ClickEvent(tag: "UIButton",
                                                                       id: "profile.save",
                                                                       text: "Save \"now\"",
                                                                       screenId: "MyApp.ProfileViewController",
                                                                       screenName: "Profile",
                                                                       timestamp: 5.0),
                                                     timestamp: 5.0,
                                                     sessionId: "test-session")),
            EventQueueItem(payload: TrackItemPayload(name: "purchase",
                                                     metricValue: 9.99,
                                                     attributes: ["currency": .string("USD")],
                                                     timestamp: 6.0,
                                                     sessionId: "test-session")),
            EventQueueItem(payload: NavigateItemPayload(name: "Profile", timestamp: 7.0, sessionId: "test-session")),
            EventQueueItem(payload: IdentifyItemPayload(options: ObservabilityOptions(),
                                                        sessionAttributes: nil,
                                                        contextKeys: ["user": "alice"],
                                                        canonicalKey: "user:alice",
                                                        timestamp: 8.0,
                                                        sessionId: "test-session")),
            EventQueueItem(payload: AppLifecycleItemPayload(signal: AppLifecycleSignal(kind: .foreground,
                                                                                       lifecycleState: "foreground",
                                                                                       timestamp: 9.0),
                                                            sessionId: "test-session"))
        ]

        var events = await generator.generateEvents(items: items)
        // Reload, Launch and the player wake-up only come from the wake-up batch.
        events += await generator.generateWakeUpEvents(items: items,
                                                       appLaunchSignal: AppLaunchSignal(launchType: .install,
                                                                                        version: "1.2.3",
                                                                                        build: "45",
                                                                                        startType: .cold,
                                                                                        timestamp: 0.5))
        events.append(Event(type: .Custom,
                            data: AnyEventData(CustomEventData(tag: .viewport,
                                                               payload: ViewportPayload(width: 320,
                                                                                        height: 480,
                                                                                        availWidth: 320,
                                                                                        availHeight: 480,
                                                                                        colorDepth: 30,
                                                                                        pixelDepth: 30,
                                                                                        orientation: 0))),
                            timestamp: 10.0,
                            _sid: 99))

        #expect(events.count > 10)
        return events
    }

    private func firstImageSource(in json: Any) -> String? {
        if let object = json as? [String: Any] {
            if let source = (object["attributes"] as? [String: Any])?["src"] as? String {
                return source
            }
            return object.values.lazy.compactMap(firstImageSource(in:)).first
        }
        if let array = json as? [Any] {
            return array.lazy.compactMap(firstImageSource(in:)).first
        }
        return nil
    }

    private func jsonObject(streaming value: JSONStreamWritable) throws -> NSDictionary {
        let writer = JSONWriter()
        value.writeJSON(to: writer)
        return try #require(JSONSerialization.jsonObject(with: writer.data) as? NSDictionary)
    }

    private func jsonObject(encoding value: Encodable) throws -> NSDictionary {
        try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? NSDictionary)
    }
}
