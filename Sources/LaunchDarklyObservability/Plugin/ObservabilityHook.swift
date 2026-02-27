import Foundation
import LaunchDarkly

/// Hook protocol adapter for native Swift SDK usage.
/// Extracts data from SDK types and delegates to ObservabilityHookExporter.
final class ObservabilityHook: Hook {
    private let exporter: ObservabilityHookExporter

    init(exporter: ObservabilityHookExporter) {
        self.exporter = exporter
    }

    public func metadata() -> Metadata {
        return Metadata(name: "Observability")
    }

    public func beforeEvaluation(
        seriesContext: EvaluationSeriesContext,
        seriesData: EvaluationSeriesData
    ) -> EvaluationSeriesData {
        let evalId = UUID().uuidString
        exporter.beforeEvaluation(evaluationId: evalId,
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

        exporter.afterEvaluation(evaluationId: evalId,
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
        exporter.afterIdentify(contextKeys: keys,
                               canonicalKey: seriesContext.context.fullyQualifiedKey(),
                               completed: true)
        return seriesData
    }
}
