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
    private let environmentMetadata: EnvironmentMetadata
    
    init(plugin: Observability,
         environmentMetadata: EnvironmentMetadata,
         withSpans: Bool = true,
         withValue: Bool = true,
         version: String,
         options: Options) {
        self.plugin = plugin
        self.environmentMetadata = environmentMetadata
        self.withSpans = withSpans
        self.withValue = withValue
        self.version = version
        self.options = options
    }
    
    public func metadata() -> Metadata {
        return Metadata(name: "Observability")
    }
    
    public func beforeEvaluation(
        seriesContext: EvaluationSeriesContext,
        seriesData: EvaluationSeriesData
    ) -> EvaluationSeriesData {
                
    
//        guard withSpans else { return seriesData }
//        //queue.sync {
//      
//        let keys = seriesContext.context.contextKeys()
//        guard let clientId = keys["ld_application"] else { return seriesData }
//       // print(keys)
//        /// Requirement 1.2.3.6
        /// https://github.com/launchdarkly/sdk-specs/tree/main/specs/OTEL-openteletry-integration#requirement-1236
        var resourceAttributes = options.resourceAttributes
        resourceAttributes[Self.SEMCONV_FEATURE_FLAG_KEY] = .string(seriesContext.flagKey)
        resourceAttributes[Self.SEMCONV_FEATURE_FLAG_PROVIDER_NAME] = .string(Self.PROVIDER_NAME)
        resourceAttributes[Self.SEMCONV_FEATURE_FLAG_CONTEXT_ID] = .string(seriesContext.context.fullyQualifiedKey())
        resourceAttributes[Self.FEATURE_FLAG_SET_ID] = .string("68bb750a25eb2b0a98b2315b")

        //  resourceAttributes[Self.FEATURE_FLAG_SET_ID] = .string(clientId)
//
        let span = LDObserve.shared.startSpan(
            name: Self.FEATURE_FLAG_SPAN_NAME,
            attributes: resourceAttributes
        )
//        
        var mutableSeriesData = seriesData
        mutableSeriesData[Self.DATA_KEY_SPAN] = span
//        
       return mutableSeriesData
    //}
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
        
//        let keys = seriesContext.context.contextKeys()
//        guard let clientId = keys["ld_application"] else { return seriesData }
  
        
       // print(keys)
        /// Requirement 1.2.3.6
        /// https://github.com/launchdarkly/sdk-specs/tree/main/specs/OTEL-openteletry-integration#requirement-1236
        var eventAttributes = options.resourceAttributes
        eventAttributes[Self.SEMCONV_FEATURE_FLAG_KEY] = .string(seriesContext.flagKey)
        eventAttributes[Self.SEMCONV_FEATURE_FLAG_PROVIDER_NAME] = .string(Self.PROVIDER_NAME)
        eventAttributes[Self.SEMCONV_FEATURE_FLAG_CONTEXT_ID] = .string(seriesContext.context.fullyQualifiedKey())
        eventAttributes[Self.FEATURE_FLAG_SET_ID] = .string("68bb750a25eb2b0a98b2315b")
       // resourceAttributes[Self.FEATURE_FLAG_SET_ID] = .string("production")

        if let lDValue = evaluationDetail.reason?[Self.CUSTOM_FEATURE_FLAG_RESULT_REASON_IN_EXPERIMENT] {
            if case let .bool(inExperiment) = lDValue {
                eventAttributes[Self.CUSTOM_FEATURE_FLAG_RESULT_REASON_IN_EXPERIMENT] = .bool(inExperiment)
            }
        }
        
        if withValue {
            if let stringified = JSON.stringify(evaluationDetail.value) {
                eventAttributes[Self.SEMCONV_FEATURE_FLAG_RESULT_VALUE] = .string(stringified) // .string is from Otel AttributeValue
            }
        }
        
        if let index = evaluationDetail.variationIndex {
            eventAttributes[Self.CUSTOM_FEATURE_FLAG_RESULT_VARIATION_INDEX] = .double(Double(index))
        }
        
        let value = seriesData[Self.DATA_KEY_SPAN]
        span.addEvent(name: Self.EVENT_NAME, attributes: eventAttributes, timestamp: Date())
        
        span.end()
        return seriesData
        //        }
    }
    
    public func afterIdentify(seriesContext: IdentifySeriesContext, seriesData: IdentifySeriesData, result: IdentifyResult) -> IdentifySeriesData {
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
    static let FEATURE_FLAG_SET_ID = "feature_flag.set.id"
    static let FEATURE_FLAG_SPAN_NAME = "evaluation"
    static let FEATURE_FLAG_CONTEXT_ATTR = "feature_flag.contextKeys"
    static let IDENTIFY_RESULT_STATUS = "identify.result.status"
}
