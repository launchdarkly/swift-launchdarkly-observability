import Foundation

public struct EventData: EventDataProtocol {
    public struct Attributes: Codable {
        var id: Int?
        var attributes: [String: String]?
    }
    
    public struct Removal: Codable {
        var parentId: Int
        var id: Int
    }
    
    public struct Addition: Codable {
        var parentId: Int
        var nextId: Int??
        var node: EventNode
    }

    var source: IncrementalSource?
    var type: MouseInteractions?
    var texts = [String]()
    var attributes: [Attributes]?
    var href: String?
    var width: Int?
    var height: Int?
    var node: EventNode?
    var removes: [Removal]?
    var adds: [Addition]?
    var id: Int?
    var x: CGFloat?
    var y: CGFloat?
    
    public init(source: IncrementalSource? = nil,
                type: MouseInteractions? = nil,
                node: EventNode? = nil,
                href: String? = nil,
                width: Int? = nil,
                height: Int? = nil,
                attributes: [Attributes]? = nil,
                adds: [Addition]? = nil,
                removes: [Removal]? = nil,
                id: Int? = nil,
                x: CGFloat? = nil,
                y: CGFloat? = nil) {
        self.source = source
        self.type = type
        self.node = node
        self.href = href
        self.width = width
        self.height = height
        self.attributes = attributes
        self.adds = adds
        self.removes = removes
        self.id = id
        self.x = x
        self.y = y
    }
}


public struct EventNode: Codable {
    public var type: NodeType
    public var name: String?
    public var tagName: String?
    public var attributes: [String: String]?
    public var childNodes: [EventNode]
    public var rootId: Int?
    public var id: Int?
    
    public init(id: Int? = nil,
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
