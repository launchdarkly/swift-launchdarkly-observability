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
        sampler: ExportSampler
    ) throws -> Self {
        guard let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(CommonOTelPath.logsPath) else {
            throw InstrumentationError.invalidLogExporterUrl
        }
        
        let exporter = MultiLogRecordExporter(
            logRecordExporters: options.isDebug ? [
                SamplingLogExporterDecorator(
                    exporter: OtlpHttpLogExporter(
                        endpoint: url,
                        envVarHeaders: options.customHeaders
                    ),
                    sampler: sampler
                ),
                LDStdoutExporter(logger: options.log)
            ] : [
                SamplingLogExporterDecorator(
                    exporter: OtlpHttpLogExporter(
                        endpoint: url,
                        envVarHeaders: options.customHeaders
                    ),
                    sampler: sampler
                )
            ]
        )
        
        return build(
            sessionService: sessionService,
            options: options,
            exporter: exporter
        )
    }
    
    static func build(
        sessionService: SessionService,
        options: Options,
        exporter: LogRecordExporter
    ) -> Self {
        guard options.logs == .enabled else {
            return .noOp
        }
        
        let service = OTelLogsService(
            sessionService: sessionService,
            options: options,
            exporter: exporter
        )
        
        return .init(
            recordLog: { service.recordLog(message: $0, severity: $1, attributes: $2) },
            flush: { await service.flush() }
        )
    }
}
