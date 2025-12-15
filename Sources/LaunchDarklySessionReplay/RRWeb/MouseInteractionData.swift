import Foundation

struct MouseInteractionData: EventDataProtocol {
    var source: IncrementalSource?
    var type: MouseInteractions?
    var texts = [String]()
    var id: Int?
    var x: CGFloat?
    var y: CGFloat?
    
    init(source: IncrementalSource? = nil,
         type: MouseInteractions? = nil,
         id: Int? = nil,
         x: CGFloat? = nil,
         y: CGFloat? = nil) {
        self.source = source
        self.type = type
        self.id = id
        self.x = x
        self.y = y
    }
}
