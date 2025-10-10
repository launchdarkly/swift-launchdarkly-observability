import Foundation

import OpenTelemetrySdk
import OpenTelemetryProtocolExporterHttp

import Sampling
import ApplicationServices

extension LogsService {
    public static let noOp: Self = .init(
        recordLog: { _, _, _ in },
        flush: { true }
    )
    
    public static func buildHttp(
        sessionService: SessionService,
        options: Options,
        sampler: ExportSampler,
        eventQueue: EventQueue
    ) throws -> Self {
        guard let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(CommonOTelPath.logsPath) else {
            throw InstrumentationError.invalidLogExporterUrl
        }
        
        let otlpExporter = OtlpHttpLogExporter(
            endpoint: url,
            envVarHeaders: options.customHeaders.map({ ($0.key, $0.value) })
        )

        let samplingExporter = SamplingLogExporterDecorator(
            exporter: otlpExporter,
            sampler: sampler
        )
            
        let exporter = MultiLogRecordExporter(
            logRecordExporters: options.isDebug ?
            [samplingExporter,  LDStdoutExporter(logger: options.log)] : [samplingExporter]
        )
    
        return build(
            sessionService: sessionService,
            options: options,
            exporter: exporter,
            eventQueue: eventQueue
        )
    }
    
    static func build(
        sessionService: SessionService,
        options: Options,
        exporter: LogRecordExporter,
        eventQueue: EventQueue
    ) -> Self {
        guard options.logs == .enabled else {
            return .noOp
        }
        
        let service = OTelLogsService(
            sessionService: sessionService,
            options: options,
            exporter: exporter,
            eventQueue: eventQueue
        )
        
        return .init(
            recordLog: { service.recordLog(message: $0, severity: $1, attributes: $2) },
            flush: { await service.flush() }
        )
    }
}
