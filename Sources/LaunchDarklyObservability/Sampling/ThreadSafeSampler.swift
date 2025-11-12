import Foundation

public final class ThreadSafeSampler {
    public static let shared = ThreadSafeSampler()
    private var generator = SystemRandomNumberGenerator()
    private let queue = DispatchQueue(label: "com.launchdarkly.sampler")
    
    private init() {}
    
    private func nextInt(in range: Range<Int>) -> Int {
        queue.sync {
            .random(in: range, using: &generator)
        }
    }
    
    public func sample(_ ratio: Int) -> Bool {
        if ratio <= 0 { return false }
        if ratio == 1 { return true }
        
        return nextInt(in: 0..<ratio) == 0
    }
}
