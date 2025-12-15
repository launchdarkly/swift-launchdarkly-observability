import Foundation

struct DomData: EventDataProtocol {
    var node: EventNode
    var canvasSize: Int
    
    init(node: EventNode, canvasSize: Int) {
        self.node = node
        self.canvasSize = canvasSize
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
