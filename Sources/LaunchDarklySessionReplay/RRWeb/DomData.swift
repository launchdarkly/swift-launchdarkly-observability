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
}

struct AddedNode: Codable {
    var parentId: Int
    var nextId: Int?
    var node: EventNode
}

struct RemovedNode: Codable {
    var parentId: Int
    var id: Int
}

struct TextMutation: Codable {
    var id: Int
    var value: String
}

struct AttributeMutation: Codable {
    var id: Int
    var attributes: [String: String?]
}

struct EventNode: Codable {
    var type: NodeType
    var name: String?
    var tagName: String?
    var attributes: [String: String]?
    var childNodes: [EventNode]
    var rootId: Int?
    var id: Int?
    
    init(id: Int? = nil,
         rootId: Int? = nil,
         type: NodeType,
         name: String? = nil,
         tagName: String? = nil,
         attributes: [String : String]? = nil,
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
