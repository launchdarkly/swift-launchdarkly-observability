import Foundation

enum JsonTestHelpers {
    static func encodeJson<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        return try cast(object, as: [String: Any].self)
    }

    static func cast<T>(_ value: Any?, as _: T.Type) throws -> T {
        guard let typed = value as? T else {
            throw CastError(description: "Could not cast \(String(describing: value)) to \(T.self)")
        }
        return typed
    }
}

struct CastError: Error, CustomStringConvertible {
    let description: String
}
