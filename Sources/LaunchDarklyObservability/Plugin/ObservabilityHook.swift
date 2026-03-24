import Foundation
import LaunchDarkly

/// Delegate protocol for observability hook callbacks.
/// `ObservabilityHookExporter` conforms to this so the hook
/// stays decoupled from the tracing / logging implementation.
protocol ObservabilityHookExporting: AnyObject {
    func beforeEvaluation(evaluationId: String, flagKey: String, contextKey: String)
    func afterEvaluation(evaluationId: String, flagKey: String, contextKey: String,
                         value: LDValue, variationIndex: Int?, reason: [String: LDValue]?)
    func afterIdentify(contextKeys: [String: String], canonicalKey: String, completed: Bool)
}

/// Hook protocol adapter for native Swift SDK usage.
/// Extracts data from SDK types and delegates to `ObservabilityHookExporting`.
final class ObservabilityHook: Hook {
    weak var delegate: ObservabilityHookExporting?

    init() {}

    public func metadata() -> Metadata {
        return Metadata(name: "Observability")
    }

    public func beforeEvaluation(
        seriesContext: EvaluationSeriesContext,
        seriesData: EvaluationSeriesData
    ) -> EvaluationSeriesData {
        let evalId = UUID().uuidString
        delegate?.beforeEvaluation(evaluationId: evalId,
                                   flagKey: seriesContext.flagKey,
                                   contextKey: seriesContext.context.fullyQualifiedKey())
        var mutableData = seriesData
        mutableData[ObservabilityHookExporter.DATA_KEY_EVAL_ID] = evalId
        return mutableData
    }

    public func afterEvaluation(
        seriesContext: EvaluationSeriesContext,
        seriesData: EvaluationSeriesData,
        evaluationDetail: LDEvaluationDetail<LDValue>
    ) -> EvaluationSeriesData {
        guard let evalId = seriesData[ObservabilityHookExporter.DATA_KEY_EVAL_ID] as? String else {
            return seriesData
        }

        delegate?.afterEvaluation(evaluationId: evalId,
                                  flagKey: seriesContext.flagKey,
                                  contextKey: seriesContext.context.fullyQualifiedKey(),
                                  value: evaluationDetail.value,
                                  variationIndex: evaluationDetail.variationIndex,
                                  reason: evaluationDetail.reason)
        return seriesData
    }

    public func afterIdentify(
        seriesContext: IdentifySeriesContext,
        seriesData: IdentifySeriesData,
        result: IdentifyResult
    ) -> IdentifySeriesData {
        guard case .complete = result else { return seriesData }
        var keys = [String: String]()
        for (k, v) in seriesContext.context.contextKeys() { keys[k] = v }
        delegate?.afterIdentify(contextKeys: keys,
                                canonicalKey: seriesContext.context.fullyQualifiedKey(),
                                completed: true)
        return seriesData
    }
}
