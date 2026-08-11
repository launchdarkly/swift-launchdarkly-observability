import OpenTelemetryApi
import OpenTelemetrySdk

protocol ExportSampler {
    var isSamplingEnabled: Bool { get }
    func sampleSpan(_ spanData: SpanData) -> SamplingResult
    func sampleLog(_ logRecord: ReadableLogRecord) -> SamplingResult
    func setConfig(_ config: SamplingConfig?)
}
