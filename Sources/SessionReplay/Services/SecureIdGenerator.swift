import Foundation
import Security

func generateSecureID() -> String {
    let idLength = 28
    let characterSet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
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
