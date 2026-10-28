import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// Stamps the global attributes onto every span at start, filling only keys the span doesn't
/// already carry.
final class GlobalAttributesSpanProcessor: SpanProcessor {
    private let store: GlobalAttributesStore
    let isStartRequired = true
    let isEndRequired = false

    init(store: GlobalAttributesStore) {
        self.store = store
    }

    func onStart(parentContext: SpanContext?, span: any ReadableSpan) {
        let globals = store.snapshot
        guard !globals.isEmpty else { return }

        let existing = span.getAttributes()
        for (key, value) in globals where existing[key] == nil {
            span.setAttribute(key: key, value: value)
        }
    }

    func onEnd(span: any ReadableSpan) {}

    func shutdown(explicitTimeout: TimeInterval?) {}

    func forceFlush(timeout: TimeInterval?) {}
}
