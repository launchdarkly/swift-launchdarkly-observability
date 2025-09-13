import OpenTelemetryApi


public struct SamplingResult {
    public let sample: Bool
    public let attributes: [String: AttributeValue]?
    
    public init(sample: Bool, attributes: [String : AttributeValue]? = nil) {
        self.sample = sample
        self.attributes = attributes
    }
}
