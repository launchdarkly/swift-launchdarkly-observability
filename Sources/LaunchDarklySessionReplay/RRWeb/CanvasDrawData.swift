import Foundation

struct CanvasDrawData: EventDataProtocol {
    public struct Command<ArgType: Codable>: Codable {
        var property: String
        var args: [ArgType]
    }
    
    var source: IncrementalSource
    var id: Int
    var type: MouseInteractions
    var commands: [AnyCommand]
    
    var canvasSize: Int {
        commands.reduce(0) { $0 + $1.canvasSize }
    }
}

enum CommandName: String, Codable {
    case clearRect
    case drawImage
}

protocol CommandPayload: Codable {
    static var property: CommandName { get }
    var property: CommandName { get }
}

struct AnyCommand: Codable {
    let value: any CommandPayload
    // Transitional
    let canvasSize: Int

    private enum K: String, CodingKey { case property }

    private static let registry: [CommandName: (Decoder) throws -> any CommandPayload] = [
        .clearRect: { try ClearRect(from: $0) },
        .drawImage: { try DrawImage(from: $0) }
    ]

    init(_ value: any CommandPayload, canvasSize: Int) {
        self.value = value
        self.canvasSize = canvasSize
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        let name = try c.decode(CommandName.self, forKey: .property)
        guard let factory = Self.registry[name] else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Unknown command \(name)"))
        }
        self.value = try factory(decoder)
        self.canvasSize = 0
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder) // concrete type encodes "property" + args
    }
}

// MARK: - Concrete commands

struct ClearRect: CommandPayload {
    static let property: CommandName = .clearRect
    let property: CommandName = .clearRect

    let x: Int, y: Int, width: Int, height: Int

    private enum K: String, CodingKey { case property, args }

    init(rect: CGRect) {
        self.x = Int(rect.minX)
        self.y = Int(rect.minY)
        self.width = Int(rect.size.width)
        self.height = Int(rect.size.height)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        // Optional: validate property matches .clearRect
        _ = try c.decode(CommandName.self, forKey: .property)
        var a = try c.nestedUnkeyedContainer(forKey: .args)
        x = try a.decode(Int.self)
        y = try a.decode(Int.self)
        width = try a.decode(Int.self)
        height = try a.decode(Int.self)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        try c.encode(Self.property, forKey: .property)
        var a = c.nestedUnkeyedContainer(forKey: .args)
        try a.encode(x)
        try a.encode(y)
        try a.encode(width)
        try a.encode(height)
    }
}

struct DrawImage: CommandPayload {
    static let property: CommandName = .drawImage
    let property: CommandName = .drawImage

    let image: AnyRRNode
    let dx: Int, dy: Int, dw: Int, dh: Int

    private enum K: String, CodingKey { case property, args }

    init(image: AnyRRNode, rect: CGRect) {
        self.image = image
        self.dx = Int(rect.minX)
        self.dy = Int(rect.minY)
        self.dw = Int(rect.size.width)
        self.dh = Int(rect.size.height)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        _ = try c.decode(CommandName.self, forKey: .property)
        var a = try c.nestedUnkeyedContainer(forKey: .args)
        image = try a.decode(AnyRRNode.self)
        dx = try a.decode(Int.self)
        dy = try a.decode(Int.self)
        dw = try a.decode(Int.self)
        dh = try a.decode(Int.self)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        try c.encode(Self.property, forKey: .property)
        var a = c.nestedUnkeyedContainer(forKey: .args)
        try a.encode(image)
        try a.encode(dx)
        try a.encode(dy)
        try a.encode(dw)
        try a.encode(dh)
    }
}

protocol RRNode: Codable {
    static var rrType: String { get }
}

struct AnyRRNode: Codable {
    let value: any RRNode

    private enum Probe: String, CodingKey { case rr_type }

    private static let registry: [String: (Decoder) throws -> any RRNode] = [
        RRImageBitmap.rrType: { try RRImageBitmap(from: $0) },
        RRBlob.rrType:        { try RRBlob(from: $0) },
        RRArrayBuffer.rrType: { try RRArrayBuffer(from: $0) }
    ]

    init(_ value: any RRNode) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Probe.self)
        let typeName = try c.decode(String.self, forKey: .rr_type)
        guard let factory = Self.registry[typeName] else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Unknown rr_type \(typeName)"))
        }
        self.value = try factory(decoder)
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder) // concrete type writes its own rr_type
    }
}

struct RRImageBitmap: RRNode {
    static let rrType = "ImageBitmap"
    let args: [AnyRRNode] // typically one Blob

    private enum K: String, CodingKey { case rr_type, args }

    init(args: [AnyRRNode]) { self.args = args }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        // Optional: validate rr_type
        _ = try c.decode(String.self, forKey: .rr_type)
        args = try c.decode([AnyRRNode].self, forKey: .args)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        try c.encode(Self.rrType, forKey: .rr_type)
        try c.encode(args, forKey: .args)
    }
}

struct RRBlob: RRNode {
    static let rrType = "Blob"
    let data: [AnyRRNode] // e.g., ArrayBuffer
    let type: String

    private enum K: String, CodingKey { case rr_type, data, type }

    init(data: [AnyRRNode], type: String) { self.data = data; self.type = type }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        _ = try c.decode(String.self, forKey: .rr_type)
        data = try c.decode([AnyRRNode].self, forKey: .data)
        type = try c.decode(String.self, forKey: .type)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        try c.encode(Self.rrType, forKey: .rr_type)
        try c.encode(data, forKey: .data)
        try c.encode(type, forKey: .type)
    }
}

struct RRArrayBuffer: RRNode {
    static let rrType = "ArrayBuffer"
    let base64: String

    private enum K: String, CodingKey { case rr_type, base64 }

    init(base64: String) { self.base64 = base64 }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        _ = try c.decode(String.self, forKey: .rr_type)
        base64 = try c.decode(String.self, forKey: .base64)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        try c.encode(Self.rrType, forKey: .rr_type)
        try c.encode(base64, forKey: .base64)
    }
}
