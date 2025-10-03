import Foundation
import OSLog

import ApplicationServices

extension SessionService {
    public static let noOp: Self = .init(
        sessionAttributes: { [:] },
        sessionInfo: { .init(id: UUID().uuidString, startTime: Date()) }
    )
    
    public static func build(
        options: Options
    ) -> Self {
        let service = MobileSessionService(
            options: .init(
                timeout: options.sessionBackgroundTimeout,
                isDebug: options.isDebug,
                log: options.log
            )
        )
        
        return .init(
            sessionAttributes: { service.sessionAttributes },
            sessionInfo: { service.sessionInfo }
        )
    }
}
