import Foundation

enum SessionReplaySampling {
    static func shouldSample(sampleRate: Double, randomValue: () -> Double = { Double.random(in: 0..<1) }) -> Bool {
        guard sampleRate > 0 else { return false }
        guard sampleRate < 1 else { return true }

        return randomValue() < sampleRate
    }
}

/// Tracks whether sampling has been decided for the current enable cycle.
internal struct SessionReplaySamplingSession {
    private(set) var decisionMade = false

    /// Returns `true` when capture should start; `false` when the session stays sampled out.
    mutating func shouldStartCapture(
        ignoreSampling: Bool,
        sampleRate: Double,
        randomValue: () -> Double = { Double.random(in: 0..<1) }
    ) -> Bool {
        if ignoreSampling {
            return true
        }
        if decisionMade {
            return false
        }
        decisionMade = true
        return SessionReplaySampling.shouldSample(sampleRate: sampleRate, randomValue: randomValue)
    }

    mutating func reset() {
        decisionMade = false
    }
}
