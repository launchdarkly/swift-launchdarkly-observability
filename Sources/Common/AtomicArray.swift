import Foundation

public class AtomicArray<T> {
    private var array = [T]()
    private let queue = DispatchQueue(label: "com.example.atomicArrayQueue")
    
    public init() { }

    public func append(_ item: T) {
        queue.sync {
            self.array.append(item)
        }
    }

    public func remove(at index: Int) {
        queue.sync {
            guard self.array.indices.contains(index) else { return }
            self.array.remove(at: index)
        }
    }
    
    public func removeAll() {
        queue.sync {
            self.array.removeAll()
        }
    }

    public var count: Int {
        var result = 0
        queue.sync {
            result = self.array.count
        }
        return result
    }
    
    public var isEmpty: Bool {
        var result = false
        queue.sync {
            result = self.array.isEmpty
        }
        return result
    }

    public subscript(index: Int) -> T? {
        var result: T?
        queue.sync {
            guard self.array.indices.contains(index) else { return }
            result = self.array[index]
        }
        return result
    }
}
