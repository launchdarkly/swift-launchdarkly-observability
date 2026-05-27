import Foundation

enum SessionReplaySampling {
    static func shouldSample(sampleRate: Double, randomValue: () -> Double = { Double.random(in: 0..<1) }) -> Bool {
        guard sampleRate > 0 else { return false }
        guard sampleRate < 1 else { return true }

        return randomValue() < sampleRate
    }
}
