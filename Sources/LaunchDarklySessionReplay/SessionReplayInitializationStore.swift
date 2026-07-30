import CryptoKit
import Foundation

/// Outcome of an `initializeSession` / `pushPayload` attempt as far as recording is concerned.
enum SessionReplayInitializationVerdict: Equatable {
    /// The backend accepted the session, so recording may run.
    case allowed
    /// The backend refused in a way retrying cannot fix (an unrecoverable status, or a GraphQL error
    /// marked non-retryable), so recording must stop for this launch.
    case unrecoverable(reason: String)
}

/// The last unrecoverable failure, as persisted between launches.
struct SessionReplayInitializationFailure: Codable, Equatable {
    let reason: String
    let timestamp: TimeInterval
}

/// Disk cache of the last unrecoverable Session Replay initialization failure, so the next launch can
/// hold off on taking screenshots until the backend has answered again.
///
/// Only failures are stored: no record means "record immediately", which keeps the common path free of
/// a startup read/write.
struct SessionReplayInitializationStore {
    static let failureKeyPrefix = "com.launchdarkly.observability.sessionReplay.lastUnrecoverableFailure"
    /// The reason is diagnostic only, and an error description can carry a whole response body, so it
    /// is kept short enough to stay cheap to read at every launch.
    static let maxReasonLength = 512

    private let defaults: UserDefaults
    private let failureKey: String

    init(sdkKey: String, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.failureKey = Self.failureKey(for: sdkKey)
    }

    /// The stored failure for this environment, or `nil` when there is none.
    func loadFailure() -> SessionReplayInitializationFailure? {
        guard let data = defaults.data(forKey: failureKey) else { return nil }
        return try? JSONDecoder().decode(SessionReplayInitializationFailure.self, from: data)
    }

    func store(reason: String, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        let failure = SessionReplayInitializationFailure(reason: String(reason.prefix(Self.maxReasonLength)),
                                                        timestamp: timestamp)
        guard let data = try? JSONEncoder().encode(failure) else { return }
        defaults.set(data, forKey: failureKey)
    }

    func clearFailure() {
        defaults.removeObject(forKey: failureKey)
    }

    /// Entitlements differ per environment, so a verdict from one must neither gate another nor
    /// overwrite what is cached for it — hence a key per SDK key rather than a shared one.
    static func failureKey(for sdkKey: String) -> String {
        "\(failureKeyPrefix).\(fingerprint(of: sdkKey))"
    }

    /// Distinguishes environments without writing the SDK key itself to disk. Only equality matters,
    /// so a truncated digest is enough.
    private static func fingerprint(of sdkKey: String) -> String {
        SHA256.hash(data: Data(sdkKey.utf8))
            .prefix(8)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
