import OpenTelemetrySdk
@testable import Observability

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

/*
import OpenTelemetrySdk
@testable import Observability

func fake(
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

final class FakeExportSampler: ExportSampler {
    var isSamplingEnabled = false
    var config: SamplingConfig?
    
    func sampleSpan(_ spanData: SpanData) -> Observability.SamplingResult {
        <#code#>
    }
    
    func sampleLog(_ logRecord: ReadableLogRecord) -> Observability.SamplingResult {
        <#code#>
    }
    
    
    
    func setConfig(_ config: SamplingConfig?) {
        self.config = config
    }
}

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
*/
