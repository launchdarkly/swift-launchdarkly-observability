#if canImport(UIKit)
import Foundation
import Testing
@testable import OpenTelemetrySdk
import OpenTelemetryApi
@testable import LaunchDarklyObservability

struct ClickSpanTests {
    private final class CapturingSpanProcessor: SpanProcessor {
        let isStartRequired = false
        let isEndRequired = true
        private(set) var ended: [SpanData] = []

        func onStart(parentContext: SpanContext?, span: any ReadableSpan) {}
        func onEnd(span: any ReadableSpan) { ended.append(span.toSpanData()) }
        func shutdown(explicitTimeout: TimeInterval?) {}
        func forceFlush(timeout: TimeInterval?) {}
    }

    private func makeTracer() -> (any Tracer, CapturingSpanProcessor) {
        let processor = CapturingSpanProcessor()
        let provider = TracerProviderBuilder().add(spanProcessor: processor).build()
        let tracer = provider.get(instrumentationName: "click-tests", instrumentationVersion: "1.0")
        return (tracer, processor)
    }

    @Test("click span uses the event.* taxonomy attributes")
    func clickSpanAttributes() {
        let (tracer, processor) = makeTracer()
        let target = TouchTarget(
            className: "UIButton",
            accessibilityIdentifier: "save_profile_btn",
            text: "Save",
            isAccessibilityElement: true,
            rectInWindow: .zero,
            rectOnScreen: .zero,
            rowIndex: nil,
            sceneId: nil
        )
        let interaction = TouchInteraction(
            id: 1,
            kind: .touchUp(CGPoint(x: 12, y: 34)),
            startTimestamp: 1000,
            timestamp: 1001,
            target: target,
            sessionId: "session-1"
        )

        interaction.startEndSpan(tracer: tracer)

        #expect(processor.ended.count == 1)
        let span = processor.ended[0]
        #expect(span.name == SemanticConvention.clickSpanName)
        #expect(span.attributes[SemanticConvention.eventType] == .string("click"))
        #expect(span.attributes[SemanticConvention.eventTag] == .string("UIButton"))
        #expect(span.attributes[SemanticConvention.eventId] == .string("save_profile_btn"))
        #expect(span.attributes[SemanticConvention.eventText] == .string("Save"))
        #expect(span.attributes[SemanticConvention.eventX] == .int(12))
        #expect(span.attributes[SemanticConvention.eventY] == .int(34))
    }

    @Test("click span omits optional fields when target data is missing")
    func clickSpanOmitsOptionalFields() {
        let (tracer, processor) = makeTracer()
        let interaction = TouchInteraction(
            id: 2,
            kind: .touchUp(CGPoint(x: 5, y: 6)),
            startTimestamp: 2000,
            timestamp: 2001,
            target: nil,
            sessionId: "session-2"
        )

        interaction.startEndSpan(tracer: tracer)

        #expect(processor.ended.count == 1)
        let span = processor.ended[0]
        #expect(span.attributes[SemanticConvention.eventType] == .string("click"))
        // Required tag falls back to "unknown" when no target is resolved.
        #expect(span.attributes[SemanticConvention.eventTag] == .string("unknown"))
        #expect(span.attributes[SemanticConvention.eventId] == nil)
        #expect(span.attributes[SemanticConvention.eventText] == nil)
        #expect(span.attributes[SemanticConvention.eventX] == .int(5))
        #expect(span.attributes[SemanticConvention.eventY] == .int(6))
    }

    @Test("click span includes event.screen_id when a current screen is known")
    func clickSpanIncludesScreenId() {
        let (tracer, processor) = makeTracer()
        let target = TouchTarget(
            className: "UITabBarButton",
            accessibilityIdentifier: "tab.search",
            text: "Search and Explore",
            isAccessibilityElement: true,
            rectInWindow: .zero,
            rectOnScreen: .zero,
            rowIndex: nil,
            sceneId: nil
        )
        let interaction = TouchInteraction(
            id: 4,
            kind: .touchUp(CGPoint(x: 120, y: 818)),
            startTimestamp: 4000,
            timestamp: 4001,
            target: target,
            sessionId: "session-4"
        )

        interaction.startEndSpan(tracer: tracer, screenId: "MyApp.MainTabViewController")

        #expect(processor.ended.count == 1)
        let span = processor.ended[0]
        #expect(span.attributes[SemanticConvention.eventScreenId] == .string("MyApp.MainTabViewController"))
        #expect(span.attributes[SemanticConvention.eventId] == .string("tab.search"))
        #expect(span.attributes[SemanticConvention.eventTag] == .string("UITabBarButton"))
    }

    @Test("click span omits event.screen_id when no current screen is known")
    func clickSpanOmitsScreenId() {
        let (tracer, processor) = makeTracer()
        let interaction = TouchInteraction(
            id: 5,
            kind: .touchUp(CGPoint(x: 1, y: 2)),
            startTimestamp: 5000,
            timestamp: 5001,
            target: nil,
            sessionId: "session-5"
        )

        interaction.startEndSpan(tracer: tracer, screenId: nil)

        #expect(processor.ended.count == 1)
        let span = processor.ended[0]
        #expect(span.attributes[SemanticConvention.eventScreenId] == nil)
    }

    @Test("non-tap interactions do not emit a click span")
    func nonTapInteractionEmitsNothing() {
        let (tracer, processor) = makeTracer()
        let interaction = TouchInteraction(
            id: 3,
            kind: .touchDown(CGPoint(x: 1, y: 2)),
            startTimestamp: 3000,
            timestamp: 3001,
            target: nil,
            sessionId: "session-3"
        )

        interaction.startEndSpan(tracer: tracer)

        #expect(processor.ended.isEmpty)
    }
}
#endif
