import Foundation

public struct ReplaySession: Codable {
    public let secureId: String
    public let projectId: String
    
    public init(secureId: String, projectId: String) {
        self.secureId = secureId
        self.projectId = projectId
    }
    
    public static func generate() -> ReplaySession {
        ReplaySession(secureId: Self.generateSecureID(), projectId: "1")
    }

    static let characterSet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    static func generateSecureID() -> String {
        let idLength = 28
        var secureID = ""
        
        for _ in 0..<idLength {
            var randomValue: UInt32 = 0
            let result = SecRandomCopyBytes(kSecRandomDefault, MemoryLayout<UInt32>.size, &randomValue)
            let index = if result == errSecSuccess {
                // Use secure random
                Int(randomValue % UInt32(characterSet.count))
            } else {
                // Fallback to pseudo-random
                Int.random(in: 0..<characterSet.count)
            }
            
            secureID.append(characterSet[index])
        }
        
        return secureID
    }
}
