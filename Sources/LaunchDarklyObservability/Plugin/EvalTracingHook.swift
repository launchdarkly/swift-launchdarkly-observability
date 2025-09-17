import Foundation
import LaunchDarkly
@preconcurrency import OpenTelemetryApi
import OpenTelemetrySdk
import Observability
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
        
        /// Requirement 1.2.3.6
        /// https://github.com/launchdarkly/sdk-specs/tree/main/specs/OTEL-openteletry-integration#requirement-1236
        lazy var span: any Span = {
            let span = tracer
                .spanBuilder(spanName: "LDClient.\(seriesContext.methodName)")
                .setStartTime(time: Date())
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
            span.addEvent(name: Self.EVENT_NAME, attributes: resourceAttributes, timestamp: Date())
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
