import Foundation
import OSLog
#if !LD_COCOAPODS
    import Common
#endif

enum SessionIdResolver {
    /// Returns the given session ID if it passes URL-path safety validation; otherwise logs an error and returns a new secure ID.
    static func resolve(sessionId: String, log: OSLog) -> String {
        if SessionIdFormatVerifier.isURLPathSafeIdentifier(sessionId) {
            return sessionId
        }
        os_log("%{public}@", log: log, type: .error, "Invalid SessionID: Using default format. Session ID \(sessionId) is invalid.")
        return SecureIDGenerator.generateSecureID()
    }
}
