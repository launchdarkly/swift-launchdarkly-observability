//
//  EventData.swift
//  swift-launchdarkly-observability
//
//  Created by Andrey Belonogov on 12/15/25.
//


import Foundation

struct EventData: EventDataProtocol {
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
    
    init(source: IncrementalSource? = nil,
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
