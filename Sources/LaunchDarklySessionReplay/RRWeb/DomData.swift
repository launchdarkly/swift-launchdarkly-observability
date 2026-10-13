import Foundation

struct DomData: EventDataProtocol {
    var node: EventNode
    // Transitional
    var canvasSize: Int
    
    init(node: EventNode, canvasSize: Int) {
        self.node = node
        self.canvasSize = canvasSize
    }
    
    private enum CodingKeys: String, CodingKey {
        case node
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.node = try container.decode(EventNode.self, forKey: .node)
        self.canvasSize = 0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(node, forKey: .node)
    }
    
    func writeJSON(to writer: JSONWriter) {
        writer.beginObject()
        writer.write(CodingKeys.node.rawValue, node)
        writer.endObject()
    }
    
    var estimatedJSONByteCount: Int { canvasSize }
}

// MARK: - DOM Mutation Data (for incremental DOM updates)

struct MutationData: EventDataProtocol {
    var source: IncrementalSource
    var adds: [AddedNode]
    var removes: [RemovedNode]
    var texts: [TextMutation]
    var attributes: [AttributeMutation]
    
    // Transitional
    var canvasSize: Int
    
    init(adds: [AddedNode] = [],
         removes: [RemovedNode] = [],
         texts: [TextMutation] = [],
         attributes: [AttributeMutation] = [],
         canvasSize: Int = 0) {
        self.source = .mutation
        self.adds = adds
        self.removes = removes
        self.texts = texts
        self.attributes = attributes
        self.canvasSize = canvasSize
    }
    
    private enum CodingKeys: String, CodingKey {
        case source, adds, removes, texts, attributes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.source = try container.decode(IncrementalSource.self, forKey: .source)
        self.adds = try container.decode([AddedNode].self, forKey: .adds)
        self.removes = try container.decode([RemovedNode].self, forKey: .removes)
        self.texts = try container.decode([TextMutation].self, forKey: .texts)
        self.attributes = try container.decode([AttributeMutation].self, forKey: .attributes)
        self.canvasSize = 0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(source, forKey: .source)
        try container.encode(adds, forKey: .adds)
        try container.encode(removes, forKey: .removes)
        try container.encode(texts, forKey: .texts)
        try container.encode(attributes, forKey: .attributes)
    }
    
    func writeJSON(to writer: JSONWriter) {
        writer.beginObject()
        writer.write(CodingKeys.source.rawValue, source)
        writer.write(CodingKeys.adds.rawValue, adds)
        writer.write(CodingKeys.removes.rawValue, removes)
        writer.write(CodingKeys.texts.rawValue, texts)
        writer.write(CodingKeys.attributes.rawValue, attributes)
        writer.endObject()
    }
    
    var estimatedJSONByteCount: Int { canvasSize }
}

struct AddedNode: Codable {
    var parentId: Int
    var nextId: Int?
    var node: EventNode
}

extension AddedNode: JSONStreamWritable {
    func writeJSON(to writer: JSONWriter) {
        writer.beginObject()
        writer.write("parentId", parentId)
        writer.writeIfPresent("nextId", nextId)
        writer.write("node", node)
        writer.endObject()
    }
}

struct RemovedNode: Codable {
    var parentId: Int
    var id: Int
}

extension RemovedNode: JSONStreamWritable {
    func writeJSON(to writer: JSONWriter) {
        writer.beginObject()
        writer.write("parentId", parentId)
        writer.write("id", id)
        writer.endObject()
    }
}

struct TextMutation: Codable {
    var id: Int
    var value: String
}

extension TextMutation: JSONStreamWritable {
    func writeJSON(to writer: JSONWriter) {
        writer.beginObject()
        writer.write("id", id)
        writer.write("value", value)
        writer.endObject()
    }
}

struct AttributeMutation: Codable {
    var id: Int
    var attributes: [String: String?]
}

extension AttributeMutation: JSONStreamWritable {
    func writeJSON(to writer: JSONWriter) {
        writer.beginObject()
        writer.write("id", id)
        writer.key("attributes")
        writer.beginObject()
        for (name, value) in attributes {
            writer.key(name)
            if let value {
                writer.write(value)
            } else {
                writer.writeNull()
            }
        }
        writer.endObject()
        writer.endObject()
    }
}

/// A DOM attribute value.
///
/// An image `src` keeps the encoded image and its MIME type instead of a `data:` URL string, and only becomes one
/// while the payload is written. A batch carries up to 9 MB of tiles, so holding each of them as base64 text on top of
/// the bytes it came from is the largest allocation the exporter makes.
enum NodeAttributeValue {
    case text(String)
    case imageDataURL(mimeType: String, data: Data)
    
    /// The value as it goes on the wire. Materializes the `data:` URL, so only `Encodable` and tests should need it.
    var stringValue: String {
        switch self {
        case .text(let value):
            return value
        case .imageDataURL(let mimeType, let data):
            return "data:\(mimeType);base64,\(data.base64EncodedString())"
        }
    }
}

extension NodeAttributeValue: Codable {
    init(from decoder: Decoder) throws {
        self = .text(try decoder.singleValueContainer().decode(String.self))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }
}

extension NodeAttributeValue: JSONStreamWritable {
    func writeJSON(to writer: JSONWriter) {
        switch self {
        case .text(let value):
            writer.write(value)
        case .imageDataURL(let mimeType, let data):
            writer.writeBase64DataURL(mimeType: mimeType, data: data)
        }
    }
}

extension NodeAttributeValue: ExpressibleByStringInterpolation {
    init(stringLiteral value: String) {
        self = .text(value)
    }
    
    init(stringInterpolation: DefaultStringInterpolation) {
        self = .text(String(stringInterpolation: stringInterpolation))
    }
}

struct EventNode: Codable {
    var type: NodeType
    var name: String?
    var tagName: String?
    var attributes: [String: NodeAttributeValue]?
    var childNodes: [EventNode]
    var rootId: Int?
    var id: Int?
    
    init(id: Int? = nil,
         rootId: Int? = nil,
         type: NodeType,
         name: String? = nil,
         tagName: String? = nil,
         attributes: [String: NodeAttributeValue]? = nil,
         childNodes: [EventNode] = []) {
        self.id = id
        self.rootId = rootId
        self.type = type
        self.name = name
        self.tagName = tagName
        self.attributes = attributes
        self.childNodes = childNodes
    }
}

extension EventNode: JSONStreamWritable {
    func writeJSON(to writer: JSONWriter) {
        writer.beginObject()
        writer.write("type", type)
        writer.writeIfPresent("name", name)
        writer.writeIfPresent("tagName", tagName)
        if let attributes {
            writer.key("attributes")
            writer.beginObject()
            for (name, value) in attributes {
                writer.key(name)
                value.writeJSON(to: writer)
            }
            writer.endObject()
        }
        writer.write("childNodes", childNodes)
        writer.writeIfPresent("rootId", rootId)
        writer.writeIfPresent("id", id)
        writer.endObject()
    }
}
