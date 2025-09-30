import Foundation
import OpenTelemetryApi

public enum MatchConfig: Codable {
    case basic(value: AttributeValue)
    case regex(expression: String)
    
    enum CodingKeys: String, CodingKey {
        case basic = "matchValue"
        case regex = "regexValue"
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let regex = try? container.decode(String.self, forKey: .regex) {
            self = .regex(expression: regex)
        } else if let value = try? container.decode(String.self, forKey: .basic) {
            self = .basic(value: .string(value))
        } else if let value = try? container.decode(Int.self, forKey: .basic) {
            self = .basic(value: .int(value))
        } else if let value = try? container.decode(Bool.self, forKey: .basic) {
            self = .basic(value: .bool(value))
        } else if let value = try? container.decode(Double.self, forKey: .basic) {
            self = .basic(value: .double(value))
        } else if let value = try? container.decode(AttributeArray.self, forKey: .basic) {
            self = .basic(value: .array(value))
        } else if let value = try? container.decode(AttributeSet.self, forKey: .basic) {
            self = .basic(value: .set(value))
        }
        else {
            throw DecodingError.typeMismatch(
                Any.self,
                    .init(codingPath: decoder.codingPath, debugDescription: "Unsupported type for MatchConfig")
            )
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .basic(let value):
            try container.encode(value, forKey: .basic)
        case .regex(let expression):
            try container.encode(expression, forKey: .regex)
        }
    }
}

public struct AttributeMatchConfig: Codable {
    public let key: MatchConfig
    public let attribute: MatchConfig
    
    public init(key: MatchConfig, attribute: MatchConfig) {
        self.key = key
        self.attribute = attribute
    }
}

public struct SpanEventMatchConfig: Codable {
    public let name: MatchConfig?
    public let attributes: [AttributeMatchConfig]?
    
    public init(name: MatchConfig? = nil, attributes: [AttributeMatchConfig] = []) {
        self.name = name
        self.attributes = attributes
    }
}

public struct SpanSamplingConfig: Codable {
    public let name: MatchConfig?
    public let attributes: [AttributeMatchConfig]?
    public let events: [SpanEventMatchConfig]?
    public let samplingRatio: Int
    
    public init(
        name: MatchConfig? = nil,
        attributes: [AttributeMatchConfig] = [],
        events: [SpanEventMatchConfig] = [],
        samplingRatio: Int
    ) {
        self.name = name
        self.attributes = attributes
        self.events = events
        self.samplingRatio = samplingRatio
    }
}

public struct LogSamplingConfig: Codable {
    public let message: MatchConfig?
    public let severityText: MatchConfig?
    public let attributes: [AttributeMatchConfig]?
    public let samplingRatio: Int
    
    public init(
        message: MatchConfig? = nil,
        severityText: MatchConfig? = nil,
        attributes: [AttributeMatchConfig] = [],
        samplingRatio: Int
    ) {
        self.message = message
        self.severityText = severityText
        self.attributes = attributes
        self.samplingRatio = samplingRatio
    }
}

public struct SamplingConfig: Codable {
    public let spans: [SpanSamplingConfig]?
    public let logs: [LogSamplingConfig]?
    
    public init(spans: [SpanSamplingConfig] = [], logs: [LogSamplingConfig] = []) {
        self.spans = spans
        self.logs = logs
    }
}

public struct SamplingData: Codable {
    public let sampling: SamplingConfig
}
