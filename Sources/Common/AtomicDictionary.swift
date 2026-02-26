import Foundation

public class AtomicDictionary<Key, Value>: CustomDebugStringConvertible, @unchecked Sendable
where Key: Hashable, Key: Sendable {
  private var storage = [Key: Value]()

    private let queue = DispatchQueue(
        label: "com.obsevabability.\(UUID().uuidString)",
        qos: .utility,
        attributes: .concurrent,
        autoreleaseFrequency: .inherit,
        target: .global()
    )

  public init() {}

  // Asynchronous barrier write:
  // callers rely on this mutation being visible after return.
  public subscript(key: Key) -> Value? {
    get { queue.sync { storage[key] }}
    set { queue.async(flags: .barrier) { [weak self] in self?.storage[key] = newValue } }
  }

  public func setValue(_ value: Value?, forKey key: Key) {
    // Synchronous barrier write:
    // callers rely on this mutation being visible immediately after return.
    queue.sync(flags: .barrier) {
      storage[key] = value
    }
  }

  public func removeValue(forKey key: Key) -> Value? {
    // Synchronous barrier remove:
    // this acts like an atomic "pop" (read + remove in one critical section).
    queue.sync(flags: .barrier) {
      storage.removeValue(forKey: key)
    }
  }

  public var debugDescription: String {
      return queue.sync { storage.debugDescription }
  }
}
