import Foundation

public struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    public init<T: Encodable>(_ wrapped: T) {
        self._encode = wrapped.encode
    }

    public func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

public struct AnyDecodable: Decodable {
    public let value: Any

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = ()
        } else if let b = try? container.decode(Bool.self) {
            self.value = b
        } else if let i = try? container.decode(Int.self) {
            self.value = i
        } else if let d = try? container.decode(Double.self) {
            self.value = d
        } else if let s = try? container.decode(String.self) {
            self.value = s
        } else if let arr = try? container.decode([AnyDecodable].self) {
            self.value = arr.map(\.value)
        } else if let dict = try? container.decode([String: AnyDecodable].self) {
            self.value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON type")
        }
    }
}

public extension AnyDecodable {
    func asEncodable() -> AnyEncodable {
        switch value {
        case let v as String: return AnyEncodable(v)
        case let v as Int: return AnyEncodable(v)
        case let v as Double: return AnyEncodable(v)
        case let v as Bool: return AnyEncodable(v)
        case is Void: return AnyEncodable(Optional<Int>.none) // encodes as null
        case let v as [Any]:
            return AnyEncodable(v.map { AnyEncodableBox($0) })
        case let v as [String: Any]:
            let mapped = v.mapValues { AnyEncodableBox($0) }
            return AnyEncodable(mapped)
        default:
            fatalError("Unsupported type: \(type(of: value))")
        }
    }
}

/// A helper to wrap `Any` into `AnyEncodable`
private func AnyEncodableBox(_ value: Any) -> AnyEncodable {
    switch value {
    case let v as String: return AnyEncodable(v)
    case let v as Int: return AnyEncodable(v)
    case let v as Double: return AnyEncodable(v)
    case let v as Bool: return AnyEncodable(v)
    case is Void: return AnyEncodable(Optional<Int>.none)
    case let v as [Any]: return AnyEncodable(v.map { AnyEncodableBox($0) })
    case let v as [String: Any]: return AnyEncodable(v.mapValues { AnyEncodableBox($0) })
    default: return AnyEncodable("\(value)")
    }
}

public func parseJSONStringToVariables(_ json: String) throws -> [String: AnyEncodable] {
    let data = Data(json.utf8)
    let decoder = JSONDecoder()
    let raw = try decoder.decode([String: AnyDecodable].self, from: data)
    return raw.mapValues { $0.asEncodable() }
}
