import Testing
import Foundation
import Combine
@testable import LaunchDarklyOtel

/// Covers the single identify funnel every path shares: the `afterIdentify` hook when an `LDClient`
/// is involved, and the manual ``LDObserve/identify(contextKeys:canonicalKey:attributes:)`` API when
/// one is not. Session Replay identifies the session off the broadcast asserted here, so it must
/// carry the identity for both.
///
/// Endpoints point at an unroutable host so constructing the service can't reach the network.
struct IdentifyFunnelTests {
    private func makeService() throws -> ObservabilityService {
        try ObservabilityService(
            options: ObservabilityOptions(
                otlpEndpoint: "http://127.0.0.1:1",
                backendUrl: "http://127.0.0.1:1"
            ),
            mobileKey: "test-key",
            sessionAttributes: [:]
        )
    }

    @Test("the manual API broadcasts the identified context")
    func manualIdentifyIsBroadcast() throws {
        let service = try makeService()
        let context = try #require(service.context)
        var received = [IdentifyEvent]()
        let cancellable = context.identifies.sink { received.append($0) }
        defer { cancellable.cancel() }

        service.identify(
            contextKeys: ["user": "user-1", "org": "org-9"],
            canonicalKey: "org:org-9:user:user-1",
            attributes: ["plan": "pro"]
        )

        #expect(received.count == 1)
        #expect(received.first?.contextKeys == ["user": "user-1", "org": "org-9"])
        #expect(received.first?.canonicalKey == "org:org-9:user:user-1")
        // Identity attributes ride along for the replay session's user, kept apart from the context
        // keys so they aren't stamped onto later spans.
        #expect(received.first?.attributes == ["plan": .string("pro")])
    }

    @Test("the key-only convenience identifies a single-kind user context")
    func keyOnlyIdentifyUsesUserKind() throws {
        let service = try makeService()
        let context = try #require(service.context)
        var received = [IdentifyEvent]()
        let cancellable = context.identifies.sink { received.append($0) }
        defer { cancellable.cancel() }

        service.identify(key: "user-1")

        #expect(received.first?.contextKeys == ["user": "user-1"])
        // A single-kind user context's fully qualified key is the key itself.
        #expect(received.first?.canonicalKey == "user-1")
        #expect(received.first?.attributes.isEmpty == true)
    }

    @Test("the client identify hook reaches the same funnel")
    func hookIdentifyIsBroadcast() throws {
        let service = try makeService()
        let context = try #require(service.context)
        var received = [IdentifyEvent]()
        let cancellable = context.identifies.sink { received.append($0) }
        defer { cancellable.cancel() }

        service.hookExporter.afterIdentify(
            contextKeys: ["user": "user-2"],
            canonicalKey: "user-2",
            completed: true
        )

        #expect(received.count == 1)
        #expect(received.first?.canonicalKey == "user-2")
    }

    @Test("an identify that did not complete is not recorded")
    func incompleteIdentifyIsIgnored() throws {
        let service = try makeService()
        let context = try #require(service.context)
        var received = [IdentifyEvent]()
        let cancellable = context.identifies.sink { received.append($0) }
        defer { cancellable.cancel() }

        service.hookExporter.afterIdentify(
            contextKeys: ["user": "user-3"],
            canonicalKey: "user-3",
            completed: false
        )

        #expect(received.isEmpty)
    }
}
