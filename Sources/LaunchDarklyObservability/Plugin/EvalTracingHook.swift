import Foundation
import LaunchDarkly
import Common

public final class EvalTracingHook: Hook {
    private let queue = DispatchQueue(label: "com.launchdarkly.eval.tracing.hook")
    private let withSpans: Bool
    private let withValue: Bool
    private let version: String
    private let options: Options
    
    public init(withSpans: Bool, withValue: Bool, version: String, options: Options) {
        self.withSpans = withSpans
        self.withValue = withValue
        self.version = version
        self.options = options
    }
    
    public func beforeEvaluation(
        seriesContext: EvaluationSeriesContext,
        seriesData: EvaluationSeriesData
    ) -> EvaluationSeriesData {
        //        queue.sync {
        guard withSpans else { return seriesData }
        
        /// Requirement 1.2.3.6
        /// https://github.com/launchdarkly/sdk-specs/tree/main/specs/OTEL-openteletry-integration#requirement-1236
        var resourceAttributes = options.resourceAttributes
        resourceAttributes[Self.SEMCONV_FEATURE_FLAG_KEY] = .string(seriesContext.flagKey)
        resourceAttributes[Self.SEMCONV_FEATURE_FLAG_PROVIDER_NAME] = .string(Self.PROVIDER_NAME)
        resourceAttributes[Self.SEMCONV_FEATURE_FLAG_CONTEXT_ID] = .string(seriesContext.context.fullyQualifiedKey())
        
        let span = LDObserve.shared.startSpan(
            name: seriesContext.methodName,
            attributes: resourceAttributes
        )
        
        var mutableSeriesData = seriesData
        mutableSeriesData[Self.DATA_KEY_SPAN] = span
        
        return mutableSeriesData
        //        }
    }
    
    public func afterEvaluation(
        seriesContext: EvaluationSeriesContext,
        seriesData: EvaluationSeriesData,
        evaluationDetail: LDEvaluationDetail<LDValue>
    ) -> EvaluationSeriesData {
        //        queue.sync {
        /// Requirement 1.2.2.2
        /// The feature_flag event MUST have the following attributes: feature_flag.key, feature_flag.provider.name, and feature_flag.context.id.
        guard let span = seriesData[Self.DATA_KEY_SPAN] as? Span else {
            return seriesData
        }

        var resourceAttributes = [String: AttributeValue]()
        resourceAttributes[Self.SEMCONV_FEATURE_FLAG_KEY] = .string(seriesContext.flagKey)
        resourceAttributes[Self.SEMCONV_FEATURE_FLAG_PROVIDER_NAME] = .string(Self.PROVIDER_NAME)
        resourceAttributes[Self.SEMCONV_FEATURE_FLAG_CONTEXT_ID] = .string(seriesContext.context.fullyQualifiedKey())
        
        if let lDValue = evaluationDetail.reason?[Self.CUSTOM_FEATURE_FLAG_RESULT_REASON_IN_EXPERIMENT] {
            if case let .bool(inExperiment) = lDValue {
                resourceAttributes[Self.CUSTOM_FEATURE_FLAG_RESULT_REASON_IN_EXPERIMENT] = .bool(inExperiment)
            }
        }
        
        if withValue {
            if let stringified = JSON.stringify(evaluationDetail.value) {
                resourceAttributes[Self.SEMCONV_FEATURE_FLAG_RESULT_VALUE] = .string(stringified) // .string is from Otel AttributeValue
            }
        }
        
        if let index = evaluationDetail.variationIndex {
            resourceAttributes[Self.CUSTOM_FEATURE_FLAG_RESULT_VARIATION_INDEX] = .double(Double(index))
        }
        
        let value = seriesData[Self.DATA_KEY_SPAN]
        span.addEvent(name: Self.EVENT_NAME, attributes: resourceAttributes, timestamp: Date())
        
        span.end()
        return seriesData
        //        }
    }
}

extension EvalTracingHook {
    static let PROVIDER_NAME = "LaunchDarkly"
    static let HOOK_NAME = "LaunchDarkly Evaluation Tracing Hook"
    static let INSTRUMENTATION_NAME = "com.launchdarkly.observability"
    static let DATA_KEY_SPAN = "variationSpan"
    static let EVENT_NAME = "feature_flag" /// RN = FEATURE_FLAG_SCOPE
    static let SEMCONV_FEATURE_FLAG_PROVIDER_NAME = "feature_flag.provider.name"
    static let SEMCONV_FEATURE_FLAG_KEY = "feature_flag.key"
    static let SEMCONV_FEATURE_FLAG_RESULT_VALUE = "feature_flag.result.value"
    static let SEMCONV_FEATURE_FLAG_CONTEXT_ID = "feature_flag.context.id"
    static let CUSTOM_FEATURE_FLAG_RESULT_VARIATION_INDEX = "feature_flag.result.variationIndex"
    static let CUSTOM_FEATURE_FLAG_RESULT_REASON_IN_EXPERIMENT = "feature_flag.result.reason.inExperiment"
    static let FEATURE_FLAG_SET_ID = "feature_flag.set.id"
    static let FEATURE_FLAG_SPAN_NAME = "evaluation" /// FEATURE_FLAG_SPAN_NAME
    static let FEATURE_FLAG_CONTEXT_ATTR = "feature_flag.contextKeys"
}
