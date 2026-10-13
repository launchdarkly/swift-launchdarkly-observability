import Foundation

/// A value that appends itself to a ``JSONWriter`` as a single JSON value.
///
/// This is the replay wire format's encoder. It exists next to the `Codable` conformances rather than replacing them
/// because `JSONEncoder` builds a boxed object tree before it writes a byte, which for a payload full of screenshots
/// means several copies of every image. Conformances are kept beside the type they encode, and
/// `PushPayloadEncodingTests` asserts that each one agrees with `JSONEncoder`.
protocol JSONStreamWritable {
    func writeJSON(to writer: JSONWriter)
}

extension JSONWriter {
    func write(_ value: JSONStreamWritable) {
        value.writeJSON(to: self)
    }

    /// Writes `value` under `name`, or writes nothing at all when it is nil, matching how a synthesized `Encodable`
    /// conformance omits nil optionals.
    func writeIfPresent(_ name: String, _ value: JSONStreamWritable?) {
        guard let value else { return }
        key(name)
        value.writeJSON(to: self)
    }

    func write(_ name: String, _ value: JSONStreamWritable) {
        key(name)
        value.writeJSON(to: self)
    }
}

extension String: JSONStreamWritable {
    func writeJSON(to writer: JSONWriter) {
        writer.write(self)
    }
}

extension Int: JSONStreamWritable {
    func writeJSON(to writer: JSONWriter) {
        writer.write(self)
    }
}

extension Int64: JSONStreamWritable {
    func writeJSON(to writer: JSONWriter) {
        writer.write(self)
    }
}

extension Double: JSONStreamWritable {
    func writeJSON(to writer: JSONWriter) {
        writer.write(self)
    }
}

extension CGFloat: JSONStreamWritable {
    func writeJSON(to writer: JSONWriter) {
        writer.write(Double(self))
    }
}

extension Bool: JSONStreamWritable {
    func writeJSON(to writer: JSONWriter) {
        writer.write(self)
    }
}

extension Array: JSONStreamWritable where Element: JSONStreamWritable {
    func writeJSON(to writer: JSONWriter) {
        writer.beginArray()
        for element in self {
            element.writeJSON(to: writer)
        }
        writer.endArray()
    }
}

/// Covers the wire enums, which are all `Int` or `String` raw values.
extension JSONStreamWritable where Self: RawRepresentable, Self.RawValue: JSONStreamWritable {
    func writeJSON(to writer: JSONWriter) {
        rawValue.writeJSON(to: writer)
    }
}
