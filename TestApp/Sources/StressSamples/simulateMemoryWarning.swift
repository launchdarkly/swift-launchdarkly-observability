import UIKit

enum SimulatedMemoryLevel {
    case low
    case veryLow
    case criticalLow
}

func simulateMemoryWarning(level: SimulatedMemoryLevel = .low) {
    #if DEBUG
    // Only works in debug mode — not allowed in production
    guard let app = UIApplication.value(forKeyPath: #keyPath(UIApplication.shared)) as? UIApplication else {
        print("Unable to access UIApplication")
        return
    }
    
    // Private selector used only for debugging purposes
    let selector = NSSelectorFromString("_performMemoryWarning")
    guard app.responds(to: selector) else {
        print("UIApplication does not respond to _performMemoryWarning")
        return
    }

    // Simulate memory pressure in stages for testing different app responses
    switch level {
    case .low:
        print("⚠️ Simulating LOW memory warning")
        app.perform(selector)
    case .veryLow:
        print("⚠️ Simulating VERY LOW memory warning")
        // Multiple calls to increase severity
        for _ in 0..<2 { app.perform(selector) }
    case .criticalLow:
        print("🚨 Simulating CRITICAL LOW memory warning")
        // Multiple calls to simulate severe pressure
        for _ in 0..<3 { app.perform(selector) }
    }
    #else
    print("⚠️ simulateMemoryWarning is only available in DEBUG builds.")
    #endif
}

import UIKit

enum MemoryPressureLevel {
    case low
    case veryLow
    case criticalLow
}

final class MemoryPressureSimulator {
    private var buffers: [Data] = []
    
    /// Simulates memory pressure without actually crashing the app.
    func simulatePressure(level: MemoryPressureLevel) {
        releaseBuffers()
        
        // Approximate MBs to allocate (tuned for safe simulation)
        let unsafeMultiplier = 20
        let megabytes: Int
        switch level {
        case .low:
            megabytes = 50 * unsafeMultiplier
        case .veryLow:
            megabytes = 150 * unsafeMultiplier
        case .criticalLow:
            megabytes = 300 * unsafeMultiplier
        }
        
        // Allocate dummy data blocks to simulate usage
        let blockSize = 10 * 1024 * 1024 // 10 MB
        let count = megabytes / 10
        print("Simulating ~\(megabytes)MB of memory pressure...")
        
        for _ in 0..<count {
//            let data = Data(count: blockSize)
            var randomBytes = [UInt8](repeating: 0, count: blockSize)
            _ = SecRandomCopyBytes(kSecRandomDefault, blockSize, &randomBytes)
            let randomData = Data(randomBytes)
            buffers.append(randomData)
        }
        
        // Post a simulated memory warning
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            NotificationCenter.default.post(
//                name: UIApplication.didReceiveMemoryWarningNotification,
//                object: nil
//            )
//            print("📉 Sent simulated memory warning for level: \(level)")
//        }
        print("📉 Sent simulated memory warning for level: \(level)")
    }
    
    func releaseBuffers() {
        buffers.removeAll()
    }
}
