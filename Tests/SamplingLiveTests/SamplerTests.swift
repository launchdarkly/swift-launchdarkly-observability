import Testing

import Sampling
@testable import SamplingLive

struct SamplerTests {
    
    @Test("defaultSampler should always return true for ratio 1")
    func defaultSamplerTrueForRatioOne() {
        #expect(ThreadSafeSampler.shared.sample(1))
    }
    
    @Test("defaultSampler should always return false for ratio 0")
    func defaultSamplerFalseForRatioZero() {
        #expect(!ThreadSafeSampler.shared.sample(0))
    }
}
