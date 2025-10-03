import Foundation

import ApplicationServices

extension TracesService {
    public static let noOp: Self = .init(
        recordError: { _, _ in },
        startSpan: { _,_  in .init(end: { _ in }) },
        flush: { true }
    )
    
    public static func build(
        sessionService: SessionService,
        options: Options
    ) throws -> Self {
        guard options.traces == .enabled else {
            return .noOp
        }
        
        let service = try OTelTraceService(sessionService: sessionService, options: options)
        
        return .init(
            recordError: {
                service.recordError(error: $0, attributes: $1)
            },
            startSpan: {
                service.startSpan(name: $0, attributes: $1)
            },
            flush: {
                service.flush()
            }
        )
    }
}


