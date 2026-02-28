import Foundation

public struct SessionIdFormatVerifier {
    /// RFC 3986 "unreserved" characters: ALPHA / DIGIT / "-" / "." / "_" / "~"
    /// This is safe for URL path segments without percent-encoding.
    public static func isURLPathSafeIdentifier(
        _ s: String,
        minLength: Int = 22,
        maxLength: Int = 128
    ) -> Bool {
        // Length bounds
        guard s.count >= minLength, s.count <= maxLength else { return false }
        
        // Disallow leading/trailing whitespace or empty-after-trim
        if s.trimmingCharacters(in: .whitespacesAndNewlines) != s { return false }
        
        // Only allow unreserved characters
        // ASCII-only on purpose to avoid visually-confusing unicode + normalization issues.
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return s.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
