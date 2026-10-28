import Foundation
import OSLog
import OpenTelemetryApi

/// Process-wide attributes applied to every span, log record and metric data point.
///
/// Globals only fill keys a signal doesn't already carry: attributes supplied on the call
/// (or set on the span builder) always win, and resource attributes rank below globals.
/// A span takes the values current when it starts.
public protocol GlobalAttributesApi {
    /// Merges `attributes` into the global attribute map by key.
    ///
    /// Keys the SDK manages itself (``SemanticConvention/sessionId``) are ignored. The map
    /// lives in memory only: it is not persisted and survives session rotation. Safe to call
    /// before the SDK is initialized.
    func setAttributes(_ attributes: [String: AttributeValue])
    /// Removes `keys` from the global attribute map. Unknown keys are ignored.
    func removeAttributes(_ keys: [String])
}

extension GlobalAttributesApi {
    public func setAttributes(_ attributes: [String: AttributeValue]) {
        GlobalAttributesStore.shared.set(attributes)
    }

    public func removeAttributes(_ keys: [String]) {
        GlobalAttributesStore.shared.remove(keys)
    }
}

/// Holds the global attribute map as an immutable snapshot swapped under a lock, so readers on
/// the hot path only copy a reference.
final class GlobalAttributesStore {
    static let shared = GlobalAttributesStore()

    static let reservedKeys: Set<String> = [SemanticConvention.sessionId]

    private let lock = NSLock()
    private var _snapshot: [String: AttributeValue] = [:]
    private let log: OSLog

    init(log: OSLog = OSLog(subsystem: "com.launchdarkly", category: "LaunchDarklyObservabilityPlugin")) {
        self.log = log
    }

    var snapshot: [String: AttributeValue] {
        lock.lock()
        defer { lock.unlock() }
        return _snapshot
    }

    func set(_ attributes: [String: AttributeValue]) {
        var accepted = attributes
        for key in attributes.keys where Self.reservedKeys.contains(key) {
            accepted.removeValue(forKey: key)
            os_log("%{public}@", log: log, type: .error, "setAttributes ignored reserved key '\(key)'")
        }
        guard !accepted.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }
        _snapshot.merge(accepted) { _, new in new }
    }

    func remove(_ keys: [String]) {
        guard !keys.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }
        for key in keys {
            _snapshot.removeValue(forKey: key)
        }
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        _snapshot = [:]
    }

    /// Returns `attributes` with every global whose key it doesn't already carry.
    func filling(_ attributes: [String: AttributeValue]) -> [String: AttributeValue] {
        let globals = snapshot
        guard !globals.isEmpty else { return attributes }
        return attributes.merging(globals) { existing, _ in existing }
    }
}
