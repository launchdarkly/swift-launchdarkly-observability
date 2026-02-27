import Foundation
import LaunchDarkly
#if !LD_COCOAPODS
import Common
#endif

/// Pure data-sending logic for observability hook tracing.
///
/// Manages span lifecycle (start/end) and identify logging.
/// Takes only simple Swift types — no Hook protocol, no @objc.
/// Both ObservabilityHook (native Swift) and ObservabilityHookProxy (C# bridge)
/// delegate here so the tracing logic is written exactly once.
final class ObservabilityHookExporter {

    private let spans: BoundedMap<String, any Span>
    private let options: Options
    private let withSpans: Bool
    private let withValue: Bool
    weak var plugin: Observability?

    init(plugin: Observability,
         withSpans: Bool,
         withValue: Bool,
         options: Options,
         maxInFlightSpans: Int = 1024) {
        self.plugin = plugin
        self.withSpans = withSpans
        self.withValue = withValue
        self.options = options
        self.spans = BoundedMap(capacity: maxInFlightSpans)
    }

    // MARK: - Evaluation

    func beforeEvaluation(evaluationId: String, flagKey: String, contextKey: String) {
        guard withSpans else { return }
        var attributes = options.resourceAttributes
        attributes[Self.SEMCONV_FEATURE_FLAG_KEY] = .string(flagKey)
        attributes[Self.SEMCONV_FEATURE_FLAG_PROVIDER_NAME] = .string(Self.PROVIDER_NAME)
        attributes[Self.SEMCONV_FEATURE_FLAG_CONTEXT_ID] = .string(contextKey)

        guard let span = plugin?.observabilityService?.traceClient.startSpan(name: Self.FEATURE_FLAG_SPAN_NAME, attributes: attributes) else { return }

        if let (_, evictedSpan) = spans.setValue(span, forKey: evaluationId) {
            evictedSpan.end()
        }
    }

    func afterEvaluation(evaluationId: String, flagKey: String, contextKey: String,
                         value: LDValue, variationIndex: Int?, reason: [String: LDValue]?) {
        sendAfterEvaluation(
            evaluationId: evaluationId,
            flagKey: flagKey,
            contextKey: contextKey,
            value: value,
            variationIndex: variationIndex,
            inExperiment: inExperiment(from: reason)
        )
    }

    func afterEvaluation(evaluationId: String, flagKey: String, contextKey: String,
                         value: NSObject, variationIndex: Int, reason: NSDictionary?) {
        sendAfterEvaluation(
            evaluationId: evaluationId,
            flagKey: flagKey,
            contextKey: contextKey,
            value: LDValue.fromFoundation(value),
            variationIndex: normalizedVariationIndex(fromRaw: variationIndex),
            inExperiment: inExperiment(fromFoundationReason: reason)
        )
    }

    private func sendAfterEvaluation(evaluationId: String, flagKey: String, contextKey: String,
                                     value: LDValue, variationIndex: Int?, inExperiment: Bool?) {
        guard let span = spans.removeValue(forKey: evaluationId) else { return }

        var attributes = options.resourceAttributes
        attributes[Self.SEMCONV_FEATURE_FLAG_KEY] = .string(flagKey)
        attributes[Self.SEMCONV_FEATURE_FLAG_PROVIDER_NAME] = .string(Self.PROVIDER_NAME)
        attributes[Self.SEMCONV_FEATURE_FLAG_CONTEXT_ID] = .string(contextKey)

        if let inExperiment = inExperiment {
            attributes[Self.CUSTOM_FEATURE_FLAG_RESULT_REASON_IN_EXPERIMENT] = .bool(inExperiment)
        }

        if withValue {
            if let stringified = JSON.stringify(value) {
                attributes[Self.SEMCONV_FEATURE_FLAG_RESULT_VALUE] = .string(stringified)
            }
        }

        if let index = variationIndex {
            attributes[Self.CUSTOM_FEATURE_FLAG_RESULT_VARIATION_INDEX] = .double(Double(index))
        }

        span.addEvent(name: Self.EVENT_NAME, attributes: attributes, timestamp: Date())
        span.end()
    }

    private func normalizedVariationIndex(fromRaw raw: Int) -> Int? {
        raw >= 0 ? raw : nil
    }

    private func inExperiment(from reason: [String: LDValue]?) -> Bool? {
        guard let reasonValue = reason?[Self.CUSTOM_FEATURE_FLAG_RESULT_REASON_IN_EXPERIMENT] else {
            return nil
        }
        if case let .bool(inExperiment) = reasonValue {
            return inExperiment
        }
        return nil
    }

    private func inExperiment(fromFoundationReason reason: NSDictionary?) -> Bool? {
        let reasonValues = [String: LDValue].fromFoundation(reason)
        return inExperiment(from: reasonValues)
    }

    // MARK: - Identify

    func afterIdentify(contextKeys: [String: String], canonicalKey: String, completed: Bool) {
        guard completed else { return }
        var attributes = [String: AttributeValue]()
        for (k, v) in contextKeys {
            attributes[k] = .string(v)
        }
        let friendlyName = options.contextFriendlyName ?? canonicalKey
        attributes["key"] = .string(friendlyName)
        attributes["canonicalKey"] = .string(canonicalKey)
        attributes[Self.IDENTIFY_RESULT_STATUS] = .string("completed")

        plugin?.observabilityService?.logClient.recordLog(
            message: "LD.identify",
            severity: .info,
            attributes: attributes
        )
    }
}

// MARK: - Constants

extension ObservabilityHookExporter {
    static let PROVIDER_NAME = "LaunchDarkly"
    static let FEATURE_FLAG_SPAN_NAME = "evaluation"
    static let EVENT_NAME = "feature_flag"
    static let SEMCONV_FEATURE_FLAG_KEY = "feature_flag.key"
    static let SEMCONV_FEATURE_FLAG_PROVIDER_NAME = "feature_flag.provider.name"
    static let SEMCONV_FEATURE_FLAG_CONTEXT_ID = "feature_flag.context.id"
    static let SEMCONV_FEATURE_FLAG_RESULT_VALUE = "feature_flag.result.value"
    static let CUSTOM_FEATURE_FLAG_RESULT_VARIATION_INDEX = "feature_flag.result.variationIndex"
    static let CUSTOM_FEATURE_FLAG_RESULT_REASON_IN_EXPERIMENT = "feature_flag.result.reason.inExperiment"
    static let IDENTIFY_RESULT_STATUS = "identify.result.status"
    static let DATA_KEY_EVAL_ID = "evaluationId"
}
