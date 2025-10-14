import Foundation
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterHttp


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

        return build(
            sessionService: sessionService,
            options: options,
            sampler: sampler,
            eventQueue: eventQueue
        )
    }
    
    static func build(
        sessionService: SessionService,
        options: Options,
        sampler: ExportSampler,
        eventQueue: EventQueue
    ) -> Self {
        guard options.logs == .enabled else {
            return .noOp
        }
        
        let service = OTelLogsService(
            sessionService: sessionService,
            options: options,
            sampler: sampler,
            eventQueue: eventQueue
        )
        
        return .init(
            recordLog: { service.recordLog(message: $0, severity: $1, attributes: $2) },
            flush: { await service.flush() }
        )
    }
}
