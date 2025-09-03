import Foundation
import LaunchDarkly
@preconcurrency import OpenTelemetryApi
import OpenTelemetrySdk
import Client
import Common

public final class EvalTracingHook: @unchecked Sendable, Hook {
    private let lock: NSLock = NSLock()
    private let withSpans: Bool
    private let withValue: Bool
    private let version: String
    
    public init(withSpans: Bool, withValue: Bool, version: String) {
        self.withSpans = withSpans
        self.withValue = withValue
        self.version = version
    }
    
    public func beforeEvaluation(
        seriesContext: EvaluationSeriesContext,
        seriesData: EvaluationSeriesData
    ) -> EvaluationSeriesData {
        lock.lock()
        defer { lock.unlock() }
        guard withSpans else { return seriesData }

        let tracer = OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: EvalTracingHook.INSTRUMENTATION_NAME,
            instrumentationVersion: version
        )
        
        lazy var span: any Span = {
            let span = tracer
                .spanBuilder(spanName: Self.FEATURE_FLAG_SPAN_NAME)
                .setStartTime(time: .now)
                .startSpan()
 
            return span
        }()
        
        var mutableSeriesData = seriesData
        mutableSeriesData[Self.DATA_KEY_SPAN] = span
        
        return mutableSeriesData
    }
    
    public func afterEvaluation(
        seriesContext: EvaluationSeriesContext,
        seriesData: EvaluationSeriesData,
        evaluationDetail: LDEvaluationDetail<LDValue>
    ) -> EvaluationSeriesData {
        
        /// Requirement 1.2.2.2
        /// The feature_flag event MUST have the following attributes: feature_flag.key, feature_flag.provider.name, and feature_flag.context.id.
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
        if let span = value as? Span {
            span.addEvent(name: Self.EVENT_NAME, attributes: resourceAttributes, timestamp: .now)
            span.end()
        }
        
        return seriesData
    }
}

extension EvalTracingHook {
    static let PROVIDER_NAME: String = "LaunchDarkly"
    static let HOOK_NAME: String = "LaunchDarkly Evaluation Tracing Hook"
    static let INSTRUMENTATION_NAME: String = "com.launchdarkly.observability"
    static let DATA_KEY_SPAN: String = "variationSpan"
    static let EVENT_NAME: String = "feature_flag" /// RN = FEATURE_FLAG_SCOPE
    static let SEMCONV_FEATURE_FLAG_CONTEXT_ID: String = "feature_flag.context.id"
    static let SEMCONV_FEATURE_FLAG_PROVIDER_NAME: String = "feature_flag.provider.name"
    static let SEMCONV_FEATURE_FLAG_KEY: String = "feature_flag.key"
    static let SEMCONV_FEATURE_FLAG_RESULT_VALUE: String = "feature_flag.result.value"
    static let CUSTOM_FEATURE_FLAG_RESULT_VARIATION_INDEX: String = "feature_flag.result.variationIndex"
    static let CUSTOM_FEATURE_FLAG_RESULT_REASON_IN_EXPERIMENT: String = "feature_flag.result.reason.inExperiment"
    static let FEATURE_FLAG_SPAN_NAME = "evaluation" /// FEATURE_FLAG_SPAN_NAME
    static let FEATURE_FLAG_CONTEXT_ATTR = "feature_flag.contextKeys"
}
/*
 export const FEATURE_FLAG_SCOPE = 'feature_flag'
 export const FEATURE_FLAG_SPAN_NAME = 'evaluation'
 export const FEATURE_FLAG_EVENT_NAME = `${FEATURE_FLAG_SCOPE}.${FEATURE_FLAG_SPAN_NAME}`
 
 export const FEATURE_FLAG_ENV_ATTR = `${FEATURE_FLAG_SCOPE}.set.id`
 export const FEATURE_FLAG_KEY_ATTR = `${FEATURE_FLAG_SCOPE}.key`
 export const FEATURE_FLAG_CONTEXT_ATTR = `${FEATURE_FLAG_SCOPE}.contextKeys`
 export const FEATURE_FLAG_CONTEXT_ID_ATTR = `${FEATURE_FLAG_SCOPE}.context.id`
 export const FEATURE_FLAG_VALUE_ATTR = `${FEATURE_FLAG_SCOPE}.result.value`
 export const FEATURE_FLAG_PROVIDER_ATTR = `${FEATURE_FLAG_SCOPE}.provider.name`
 */

/*
 export const FEATURE_FLAG_SCOPE = 'feature_flag'
 export const FEATURE_FLAG_SPAN_NAME = 'evaluation'
 export const FEATURE_FLAG_EVENT_NAME = `${FEATURE_FLAG_SCOPE}.${FEATURE_FLAG_SPAN_NAME}`

 export const FEATURE_FLAG_KEY_ATTR = `${FEATURE_FLAG_SCOPE}.key`
 export const FEATURE_FLAG_VALUE_ATTR = `${FEATURE_FLAG_SCOPE}.result.value`
 export const FEATURE_FLAG_VARIATION_INDEX_ATTR = `${FEATURE_FLAG_SCOPE}.result.variationIndex`
 export const FEATURE_FLAG_PROVIDER_ATTR = `${FEATURE_FLAG_SCOPE}.provider.name`
 export const FEATURE_FLAG_CONTEXT_ATTR = `${FEATURE_FLAG_SCOPE}.context`
 export const FEATURE_FLAG_CONTEXT_ID_ATTR = `${FEATURE_FLAG_SCOPE}.context.id`
 export const FEATURE_FLAG_ENV_ATTR = `${FEATURE_FLAG_SCOPE}.environment.id`

 export const LD_SCOPE = 'launchdarkly'
 export const FEATURE_FLAG_APP_ID_ATTR = `${LD_SCOPE}.application.id`
 export const FEATURE_FLAG_APP_VERSION_ATTR = `${LD_SCOPE}.application.version`
 export const LD_IDENTIFY_RESULT_STATUS = `${LD_SCOPE}.identify.result.status`
 */
