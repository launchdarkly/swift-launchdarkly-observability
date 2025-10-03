import Foundation

import ApplicationServices

extension MetricsService {
    public static let noOp: Self = MetricsService(
        recordMetric: { _ in },
        recordCount: { _ in },
        recordIncr: { _ in },
        recordHistogram: { _ in },
        recordUpDownCounter: { _ in },
        flush: { true }
    )
    
    public static func build(
        sessionService: SessionService,
        options: Options
    ) throws -> Self {
        guard options.metrics == .enabled else {
            return .noOp
        }
        
        let service = try OTelMetricsService(sessionService: sessionService, options: options)
        
        return .init(
            recordMetric: { service.recordMetric(metric: $0) },
            recordCount: { service.recordCount(metric: $0) },
            recordIncr: { service.recordIncr(metric: $0) },
            recordHistogram: { service.recordHistogram(metric: $0) },
            recordUpDownCounter: { service.recordUpDownCounter(metric: $0) },
            flush: { service.flush() }
        )
    }
}


