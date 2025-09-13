import Foundation

//
//struct Sampling: Codable {
////    let logs: []
//}
//
//enum CodableValue: Codable {
//    case string(String)
//    case int(Int)
//    case double(Double)
//    case bool(Bool)
//
//    init(from decoder: Decoder) throws {
//        let container = try decoder.singleValueContainer()
//        if let str = try? container.decode(String.self) {
//            self = .string(str)
//        } else if let int = try? container.decode(Int.self) {
//            self = .int(int)
//        } else if let dbl = try? container.decode(Double.self) {
//            self = .double(dbl)
//        } else if let bool = try? container.decode(Bool.self) {
//            self = .bool(bool)
//        } else {
//            throw DecodingError.typeMismatch(CodableValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown type for CodableValue"))
//        }
//    }
//
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//        switch self {
//        case .string(let str):
//            try container.encode(str)
//        case .int(let int):
//            try container.encode(int)
//        case .double(let dbl):
//            try container.encode(dbl)
//        case .bool(let bool):
//            try container.encode(bool)
//        }
//    }
//}

/*
struct RootCodable: Codable {
    let data: DataClassCodable
}

struct DataClassCodable: Codable {
    let sampling: SamplingCodable
}

struct SamplingCodable: Codable {
    let logs: [LogCodable]
    let spans: [SpanCodable]
}

struct LogCodable: Codable {
    let severityText: SeverityTextCodable?
    let message: MessageCodable?
    let attributes: [AttributeCodable]?
    let samplingRatio: Int
}

struct SeverityTextCodable: Codable {
    let matchValue: String?
    let regexValue: String?
}

struct MessageCodable: Codable {
    let matchValue: String?
    let regexValue: String?
}

struct AttributeCodable: Codable {
    let key: KeyCodable
    let attribute: AttributeCodableValue
}

struct KeyCodable: Codable {
    let matchValue: String?
    let regexValue: String?
}

struct AttributeCodableValue: Codable {
    let matchValue: CodableValue?
    let regexValue: String?
}

enum CodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let dbl = try? container.decode(Double.self) {
            self = .double(dbl)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else {
            throw DecodingError.typeMismatch(CodableValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown type for CodableValue"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str):
            try container.encode(str)
        case .int(let int):
            try container.encode(int)
        case .double(let dbl):
            try container.encode(dbl)
        case .bool(let bool):
            try container.encode(bool)
        }
    }
}

struct SpanCodable: Codable {
    let name: NameCodable?
    let events: [EventCodable]?
    let attributes: [AttributeCodable]?
    let samplingRatio: Int
}

struct NameCodable: Codable {
    let matchValue: String?
    let regexValue: String?
}

struct EventCodable: Codable {
    let name: NameCodable?
    let attributes: [AttributeCodable]?
}

func loadRootConfig(from filePath: String) -> RootCodable? {
    let url = URL(fileURLWithPath: filePath)
    do {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let root = try decoder.decode(RootCodable.self, from: data)
        return root
    } catch {
        print("Error loading or parsing Config.json: \(error)")
        return nil
    }
}

func matchConfig(fromNameCodable nameCodable: NameCodable?) -> MatchConfig? {
    nameCodable.flatMap {
        if let matchValue = $0.matchValue {
            return MatchConfig.basic(value: matchValue)
        } else if let regexValue = $0.regexValue {
            return MatchConfig.regex(expression: regexValue)
        } else {
            return nil
        }
    }
}

func keyCodableToMatchConfig(_ keyCodable: KeyCodable) -> MatchConfig? {
    if let matchValue = keyCodable.matchValue {
        return .basic(value: matchValue)
    } else if let regexValue = keyCodable.regexValue {
        return .regex(expression: regexValue)
    } else {
        return nil
    }
}

func attributeMatchConfig(from attributeCodable: AttributeCodable) -> AttributeMatchConfig {
    .init(
        key: keyCodableToMatchConfig(attributeCodable.key),
        attribute: <#T##MatchConfig#>
    )
}

func transformToSpanSamplingConfig(_ spanCodable: SpanCodable) -> SpanSamplingConfig {
    .init(
        name: matchConfig(fromNameCodable: spanCodable.name),
        attributes: <#T##[AttributeMatchConfig]#>,
        events: <#T##[SpanEventMatchConfig]#>,
        samplingRatio: <#T##Int#>
    )
}

//func transformToSamplingConfig(_ root: RootCodable) -> SamplingConfig {
//    .init(
//        spans: root.data.sampling.spans.map(<#T##transform: (SpanCodable) throws(Error) -> T##(SpanCodable) throws(Error) -> T#>),
//        logs: <#T##[LogSamplingConfig]#>
//    )
//}

*/
