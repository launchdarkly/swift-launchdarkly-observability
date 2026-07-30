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
    /// Fingerprint of the SDK key the failure was produced for. Entitlements differ per environment,
    /// so a verdict from one must not gate another.
    let environment: String
}

/// Disk cache of the last unrecoverable Session Replay initialization failure, so the next launch can
/// hold off on taking screenshots until the backend has answered again.
///
/// Only failures are stored: no record means "record immediately", which keeps the common path free of
/// a startup read/write.
struct SessionReplayInitializationStore {
    static let failureKey = "com.launchdarkly.observability.sessionReplay.lastUnrecoverableFailure"
    /// The reason is diagnostic only, and an error description can carry a whole response body, so it
    /// is kept short enough to stay cheap to read at every launch.
    static let maxReasonLength = 512

    private let defaults: UserDefaults
    private let environment: String

    init(sdkKey: String, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.environment = Self.fingerprint(of: sdkKey)
    }

    /// The stored failure, or `nil` when there is none or it belongs to a different environment.
    func loadFailure() -> SessionReplayInitializationFailure? {
        guard let data = defaults.data(forKey: Self.failureKey),
              let failure = try? JSONDecoder().decode(SessionReplayInitializationFailure.self, from: data),
              failure.environment == environment else {
            return nil
        }
        return failure
    }

    func store(reason: String, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        let failure = SessionReplayInitializationFailure(reason: String(reason.prefix(Self.maxReasonLength)),
                                                        timestamp: timestamp,
                                                        environment: environment)
        guard let data = try? JSONEncoder().encode(failure) else { return }
        defaults.set(data, forKey: Self.failureKey)
    }

    func clearFailure() {
        defaults.removeObject(forKey: Self.failureKey)
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
