import Testing
import Foundation
@testable import LaunchDarklySessionReplay

struct JSONWriterTests {
    private func written(_ build: (JSONWriter) -> Void) -> String {
        let writer = JSONWriter()
        build(writer)
        return String(data: writer.data, encoding: .utf8) ?? ""
    }

    @Test("Separates values, keys and nested containers")
    func separatesValuesKeysAndNestedContainers() {
        let json = written { writer in
            writer.beginObject()
            writer.key("name")
            writer.write("replay")
            writer.key("ids")
            writer.beginArray()
            writer.write(1)
            writer.write(2)
            writer.endArray()
            writer.key("nested")
            writer.beginObject()
            writer.key("on")
            writer.write(true)
            writer.endObject()
            writer.endObject()
        }

        #expect(json == #"{"name":"replay","ids":[1,2],"nested":{"on":true}}"#)
    }

    @Test("Writes empty containers")
    func writesEmptyContainers() {
        let json = written { writer in
            writer.beginArray()
            writer.beginObject()
            writer.endObject()
            writer.endArray()
        }

        #expect(json == "[{}]")
    }

    @Test("Escapes what JSON requires and passes multi-byte UTF-8 through")
    func escapesWhatJSONRequires() {
        let value = "quote:\" backslash:\\ tab:\t newline:\n control:\u{01} slash:/ emoji:🙂"
        let json = written { $0.write(value) }

        #expect(json == #""quote:\" backslash:\\ tab:\t newline:\n control:\u0001 slash:/ emoji:🙂""#)
        let parsed = try? JSONSerialization.jsonObject(with: Data(json.utf8), options: [.fragmentsAllowed]) as? String
        #expect(parsed == value)
    }

    @Test("Writes integers, including the boundaries")
    func writesIntegers() {
        #expect(written { $0.write(0) } == "0")
        #expect(written { $0.write(-7) } == "-7")
        #expect(written { $0.write(Int64.min) } == "\(Int64.min)")
        #expect(written { $0.write(Int64.max) } == "\(Int64.max)")
    }

    @Test("Writes integral doubles as plain integers and the rest round-trip")
    func writesDoubles() {
        #expect(written { $0.write(11.0 as Double) } == "11")
        #expect(written { $0.write(-0.0 as Double) } == "0")
        #expect(written { $0.write(0.5 as Double) } == "0.5")
        #expect(written { $0.write(1e300 as Double) } == "1e+300")
    }

    @Test("Writes null for a non-finite double and reports it")
    func writesNullForNonFiniteDouble() {
        let writer = JSONWriter()
        writer.write(Double.infinity)

        #expect(String(data: writer.data, encoding: .utf8) == "null")
        #expect(writer.wroteNonFiniteNumber)
    }

    @Test("Reset clears the buffer and the separator state")
    func resetClearsBuffer() {
        let writer = JSONWriter()
        writer.beginArray()
        writer.write(Double.nan)
        let kept = writer.data
        writer.reset()
        writer.write("after")

        #expect(String(data: kept, encoding: .utf8) == "[null")
        #expect(String(data: writer.data, encoding: .utf8) == #""after""#)
        #expect(writer.byteCount == 7)
        #expect(!writer.wroteNonFiniteNumber)
    }

    @Test("Base64 data URLs match Foundation, at every padding length")
    func base64DataURLsMatchFoundation() {
        for byteCount in 0...16 {
            let data = Data((0..<byteCount).map { UInt8(($0 &* 37 &+ 11) % 256) })
            let json = written { $0.writeBase64DataURL(mimeType: "image/jpeg", data: data) }
            let expected = "data:image/jpeg;base64,\(data.base64EncodedString())"

            #expect(json == "\"\(expected)\"")
            #expect(JSONWriter.base64DataURLByteCount(mimeType: "image/jpeg", byteCount: byteCount) == expected.utf8.count)
        }
    }

    @Test("Base64 data URLs match Foundation for bytes that use the whole alphabet")
    func base64DataURLsMatchFoundationForAllByteValues() {
        let data = Data((0...255).map { UInt8($0) })
        let json = written { $0.writeBase64DataURL(mimeType: "image/png", data: data) }

        #expect(json == "\"data:image/png;base64,\(data.base64EncodedString())\"")
    }
}
