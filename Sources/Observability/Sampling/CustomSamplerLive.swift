/*
import Foundation

extension ExportSampler {
    
    /// maintained for compatibility purposes
    public static func customSampler(
        sampler: ((Int) -> Bool)? = nil
    ) -> Self {
        
        return build(
            sampler: sampler
        )
    }
    
    public static func build(
        sampler: ((Int) -> Bool)? = nil
    ) -> Self {
        
        
        let sampler = CustomSampler(sampler: sampler)
    
        return .init(
            sampleSpan: { sampler.sampleSpan($0) },
            sampleLog: { sampler.sampleLog($0) },
            isSamplingEnabled: { sampler.isSamplingEnabled() },
            setConfig: { sampler.setConfig($0) }
        )
    }
}
*/
