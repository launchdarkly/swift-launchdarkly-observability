import Foundation
import LaunchDarkly
#if !LD_COCOAPODS
    import Common
#endif

final class ObservabilityHook: Hook {
    private let queue = DispatchQueue(label: "com.launchdarkly.eval.tracing.hook")
    private let plugin: Observability
    private let withSpans: Bool
    private let withValue: Bool
    private let version: String
    private let options: Options
    
    init(plugin: Observability,
         withSpans: Bool,
         withValue: Bool,
         version: String,
         options: Options) {
        self.plugin = plugin
        self.withSpans = withSpans
        self.withValue = withValue
        self.version = version
        self.options = options
        
        
//        const metaAttrs = {
//                [ATTR_TELEMETRY_SDK_NAME]: metadata.sdk.name,
//                [ATTR_TELEMETRY_SDK_VERSION]: metadata.sdk.version,
//                [FEATURE_FLAG_ENV_ATTR]: metadata.clientSideId,
//                [FEATURE_FLAG_PROVIDER_ATTR]: 'LaunchDarkly',
//                ...(metadata.application?.id
//                    ? { [FEATURE_FLAG_APP_ID_ATTR]: metadata.application.id }
//                    : {}),
//                ...(metadata.application?.version
//                    ? {
//                            [FEATURE_FLAG_APP_VERSION_ATTR]:
//                                metadata.application.version,
//                        }
//                    : {}),
//            }
    }
    
    public func beforeEvaluation(
        seriesContext: EvaluationSeriesContext,
        seriesData: EvaluationSeriesData
    ) -> EvaluationSeriesData {
//        queue.sync {
            guard withSpans else { return seriesData }
            
            /// Requirement 1.2.3.6
            /// https://github.com/launchdarkly/sdk-specs/tree/main/specs/OTEL-openteletry-integration#requirement-1236
            let span = LDObserve.shared.startSpan(
                name: "LDClient.\(seriesContext.methodName)",
                attributes: options.resourceAttributes
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
//        }
    }
    
    public func afterIdentify(seriesContext: IdentifySeriesContext, seriesData: EvaluationSeriesData, result: IdentifyResult) -> EvaluationSeriesData {
        // Log identify completion with context metadata
        // Note: We conservatively include the canonical context key and status.
        // Resource attributes are already attached by the log builder.
        guard case .complete = result else {
            return seriesData
        }
        
        let context = seriesContext.context
        var attributes = [String: AttributeValue]()
        for (k, v) in context.contextKeys() {
            attributes[k] = .string(v)
        }
        
        let canonicalKey = context.fullyQualifiedKey()
        attributes["key"] = .string(options.contextFriendlyName ?? canonicalKey)
        attributes["canonicalKey"] = .string(canonicalKey)
        attributes[Self.IDENTIFY_RESULT_STATUS] = .string("completed")
        
        plugin.observabilityService?.logClient.recordLog(
            message: "LD.identify",
            severity: .info,
            attributes: attributes
        )
        
        return seriesData
    }
}

extension ObservabilityHook {
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
    static let IDENTIFY_RESULT_STATUS = "identify.result.status"
}
