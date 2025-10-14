@testable import OpenTelemetrySdk
import OpenTelemetryApi
@testable import Observability

extension ExportSampler {
    static func fake(
        sampleSpan: @escaping (SpanData) -> SamplingResult = { _ in .init(sample: true) },
        sampleLog: @escaping (ReadableLogRecord) -> SamplingResult = { _ in .init(sample: true) },
        isSamplingEnabled: Bool = true
    ) -> ExportSampler {
        final class FakeExportSampler {
            var config: SamplingConfig?
            
            func setConfig(_ config: SamplingConfig?) {
                self.config = config
            }
        }
        let fakeExportSampler = FakeExportSampler()
        return .init(
            sampleSpan: sampleSpan,
            sampleLog: sampleLog,
            isSamplingEnabled: { isSamplingEnabled },
            setConfig: { fakeExportSampler.setConfig($0) }
        )
    }
}
