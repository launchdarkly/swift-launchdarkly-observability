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
