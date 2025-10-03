import Foundation

import ApplicationServices

extension LogsService {
    public static let noOp: Self = .init(
        recordLog: { _, _, _ in },
        flush: { true }
    )
    
    public static func build(
        sessionService: SessionService,
        options: Options
    ) throws -> Self {
        guard options.logs == .enabled else {
            return .noOp
        }
        
        let service = try OTelLogsService(sessionService: sessionService, options: options)
        
        return .init(
            recordLog: { service.recordLog(message: $0, severity: $1, attributes: $2) },
            flush: { service.flush() }
        )
    }
}
