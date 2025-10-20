import Foundation

public struct MouseMoveEventData: EventDataProtocol {
    public struct Position: Codable {
        var x: Int
        var y: Int
        var id: String?
        var timeOffset: Int64
        
        init(x: CGFloat, y: CGFloat, id: String? = nil, timeOffset: TimeInterval) {
            self.x = Int(x)
            self.y = Int(y)
            self.id = id
            self.timeOffset = timeOffset.milliseconds
        }
    }
    
    var source: IncrementalSource
    var positions: [Position]?
    
    init(source: IncrementalSource, positions: [Position]? = nil) {
        self.source = source
        self.positions = positions
    }
}
