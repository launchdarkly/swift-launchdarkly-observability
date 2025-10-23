import Foundation

/// A configurable CPU load generator
final class CpuLoadGenerator: ObservableObject {
//    static let shared = CpuLoadGenerator()
    
    private var isRunning = false
    private var workers: [DispatchWorkItem] = []
    private let queue = DispatchQueue(label: "CPULoader.queue", attributes: .concurrent)
    
    /// Number of parallel worker threads (default = number of CPU cores)
    private var threadCount = ProcessInfo.processInfo.processorCount
    /// Target CPU load percentage (0.0 ... 1.0, where 1.0 = 100%)
    private var loadFactor: Double = 1.0
    
//    private init() {}
    
    /// Start generating CPU load.
    /// - Parameters:
    ///   - threads: Number of parallel worker threads.
    ///   - load: Target load (0.0–1.0) where 1.0 = 100%.
    func startLoad(threads: Int? = nil, load: Double? = nil) {
        guard !isRunning else { return }
        isRunning = true
        
        if let threads = threads { threadCount = max(1, threads) }
        if let load = load { loadFactor = min(max(load, 0.0), 1.0) }
        
        workers.removeAll()
        
        print("🔥 Starting CPU load on \(threadCount) threads at \(Int(loadFactor * 100))% intensity.")
        
        for core in 0..<threadCount {
            let workItem = DispatchWorkItem { [weak self] in
                self?.loadLoop(core: core)
            }
            workers.append(workItem)
            queue.async(execute: workItem)
        }
    }
    
    /// Stop all running computations.
    func stopLoad() {
        guard isRunning else { return }
        isRunning = false
        workers.forEach { $0.cancel() }
        workers.removeAll()
        print("🧊 CPU load stopped.")
    }
    
    /// Toggle start/stop.
    func toggle(threads: Int? = nil, load: Double? = nil) {
        isRunning ? stopLoad() : startLoad(threads: threads, load: load)
    }
    
    /// Internal heavy computation loop that respects target CPU load.
    private func loadLoop(core: Int) {
        let activeTime = loadFactor * 0.1  // work for this fraction of 100ms
        let sleepTime = 0.1 - activeTime   // rest for the remainder
        
        while isRunning && !Thread.current.isCancelled {
            let start = CFAbsoluteTimeGetCurrent()
            
            // Perform computation for `activeTime` seconds
            while (CFAbsoluteTimeGetCurrent() - start) < activeTime {
                _ = sqrt(12345.6789) * sin(9876.54321)
            }
            
            // Sleep for remaining period to control load
            if sleepTime > 0 {
                Thread.sleep(forTimeInterval: sleepTime)
            }
        }
        
        print("💤 Worker \(core) stopped.")
    }
}
