import OpenTelemetrySdk
@testable import LaunchDarklyObservability

final class FakeExportSampler: ExportSampler {
    var isSamplingEnabled = false
    var config: SamplingConfig?
    var _sampleSpan: (SpanData) -> SamplingResult
    var _sampleLog: (ReadableLogRecord) -> SamplingResult
    
    init(
        isSamplingEnabled: Bool = false,
        config: SamplingConfig? = nil,
        sampleSpan: @escaping (SpanData) -> SamplingResult = { _ in .init(sample: true) },
        sampleLog: @escaping (ReadableLogRecord) -> SamplingResult = { _ in .init(sample: true) },
    ) {
        self.isSamplingEnabled = isSamplingEnabled
        self.config = config
        self._sampleSpan = sampleSpan
        self._sampleLog = sampleLog
    }
    
    func sampleSpan(_ spanData: SpanData) -> SamplingResult {
        _sampleSpan(spanData)
    }
    
    func sampleLog(_ logRecord: ReadableLogRecord) -> SamplingResult {
        _sampleLog(logRecord)
    }

    func setConfig(_ config: SamplingConfig?) {
        self.config = config
    }
}
