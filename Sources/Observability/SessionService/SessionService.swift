import Foundation
import Common

public struct SessionService {
    public var sessionAttributes: () -> [String: AttributeValue]
    public var sessionInfo: () -> SessionInfo
    
    public init(
        sessionAttributes: @escaping () -> [String : AttributeValue],
        sessionInfo: @escaping () -> SessionInfo
    ) {
        self.sessionAttributes = sessionAttributes
        self.sessionInfo = sessionInfo
    }
    
}
