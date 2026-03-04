import Foundation
import LaunchDarkly

#if !LD_COCOAPODS
import Common
#endif

/// @objc adapter for the C# / MAUI bridge.
/// Converts Foundation types (NSObject, NSDictionary) to Swift types
/// and delegates to ObservabilityHookExporter.
@objc(ObservabilityHookProxy)
public final class ObservabilityHookProxy: NSObject {
    private let exporter: ObservabilityHookExporter

    init(exporter: ObservabilityHookExporter) {
        self.exporter = exporter
        super.init()
    }

    @objc(beforeEvaluationWithId:flagKey:contextKey:)
    public func beforeEvaluation(evaluationId: String, flagKey: String, contextKey: String) {
        exporter.beforeEvaluation(evaluationId: evaluationId, flagKey: flagKey, contextKey: contextKey)
    }

    @objc(afterEvaluationWithId:flagKey:contextKey:value:variationIndex:reason:)
    public func afterEvaluation(evaluationId: String, flagKey: String, contextKey: String,
                                value: NSObject, variationIndex: Int, reason: NSDictionary?) {
        exporter.afterEvaluation(evaluationId: evaluationId, flagKey: flagKey, contextKey: contextKey,
                                 value: value, variationIndex: variationIndex, reason: reason)
    }

    @objc(afterIdentifyWithContextKeys:canonicalKey:completed:)
    public func afterIdentify(contextKeys: NSDictionary, canonicalKey: String, completed: Bool) {
        var keys = [String: String]()
        for (k, v) in contextKeys {
            if let key = k as? String, let val = v as? String { keys[key] = val }
        }
        exporter.afterIdentify(contextKeys: keys, canonicalKey: canonicalKey, completed: completed)
    }
}
