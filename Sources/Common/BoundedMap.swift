import Foundation

/// Thread-safe bounded dictionary with FIFO eviction.
///
/// - Insertions beyond `capacity` evict the oldest key/value pair.
/// - `setValue` and eviction happen atomically in one barrier section.
public final class BoundedMap<Key, Value>: @unchecked Sendable
where Key: Hashable, Key: Sendable {
    private var storage = [Key: Value]()
    private var insertionOrder = [Key]()
    private let capacity: Int

    private let queue = DispatchQueue(
        label: "com.observability.bounded-map.\(UUID().uuidString)",
        qos: .utility,
        attributes: .concurrent,
        autoreleaseFrequency: .inherit,
        target: .global()
    )

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    /// Atomically sets a value and optionally evicts the oldest item.
    /// - Returns: Evicted key/value if capacity overflow occurs, otherwise nil.
    @discardableResult
    public func setValue(_ value: Value, forKey key: Key) -> (key: Key, value: Value)? {
        queue.sync(flags: .barrier) {
            if storage[key] != nil, let idx = insertionOrder.firstIndex(of: key) {
                insertionOrder.remove(at: idx)
            }

            storage[key] = value
            insertionOrder.append(key)

            guard insertionOrder.count > capacity else { return nil }
            let evictedKey = insertionOrder.removeFirst()
            guard let evictedValue = storage.removeValue(forKey: evictedKey) else { return nil }
            return (evictedKey, evictedValue)
        }
    }

    /// Atomically removes and returns the value for a key.
    public func removeValue(forKey key: Key) -> Value? {
        queue.sync(flags: .barrier) {
            let removed = storage.removeValue(forKey: key)
            if removed != nil, let idx = insertionOrder.firstIndex(of: key) {
                insertionOrder.remove(at: idx)
            }
            return removed
        }
    }

    public var count: Int {
        queue.sync { storage.count }
    }
}
