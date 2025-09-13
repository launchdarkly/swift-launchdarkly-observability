import OpenTelemetryApi
import OpenTelemetrySdk

public struct ExportSampler {
    public var sampleSpan: (SpanData) -> SamplingResult
    public var sampleLog: (ReadableLogRecord) -> SamplingResult
    public var isSamplingEnabled: () -> Bool
    public var setConfig: (_ config: SamplingConfig?) -> Void
    
    public init(
        sampleSpan: @escaping (SpanData) -> SamplingResult,
        sampleLog: @escaping (ReadableLogRecord) -> SamplingResult,
        isSamplingEnabled: @escaping () -> Bool,
        setConfig: @escaping (_: SamplingConfig?) -> Void
    ) {
        self.sampleSpan = sampleSpan
        self.sampleLog = sampleLog
        self.isSamplingEnabled = isSamplingEnabled
        self.setConfig = setConfig
    }
}
