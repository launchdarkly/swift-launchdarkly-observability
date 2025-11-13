import OpenTelemetryApi


public struct SamplingResult {
    public let sample: Bool
    public let attributes: [String: OpenTelemetryApi.AttributeValue]?
    
    public init(sample: Bool, attributes: [String : OpenTelemetryApi.AttributeValue]? = nil) {
        self.sample = sample
        self.attributes = attributes
    }
}
