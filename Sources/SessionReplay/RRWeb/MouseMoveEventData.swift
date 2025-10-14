public struct MouseMoveEventData: EventDataProtocol {
    public struct Position: Codable {
        var x: Int
        var y: Int
        var id: String?
        var timeOffset: Int64
        
        init(x: Int, y: Int, id: String? = nil, timeOffset: Int64) {
            self.x = x
            self.y = y
            self.id = id
            self.timeOffset = timeOffset
        }
    }
    
    var source: IncrementalSource
    var positions: [Position]?
    
    init(source: IncrementalSource, positions: [Position]? = nil) {
        self.source = source
        self.positions = positions
    }
}
