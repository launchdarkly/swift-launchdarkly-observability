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
