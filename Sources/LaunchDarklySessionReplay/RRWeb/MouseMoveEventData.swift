import Foundation

struct MouseMoveEventData: EventDataProtocol {
    struct Position: Codable {
        var x: Int
        var y: Int
        var id: Int?
        var timeOffset: Int64
        
        init(x: CGFloat, y: CGFloat, id: Int? = nil, timeOffset: TimeInterval) {
            self.x = Int(x)
            self.y = Int(y)
            self.id = id
            self.timeOffset = timeOffset.milliseconds
        }
    }
    
    var source: IncrementalSource
    var positions: [Position]
    
    init(source: IncrementalSource, positions: [Position]) {
        self.source = source
        self.positions = positions
    }
    
    func writeJSON(to writer: JSONWriter) {
        writer.beginObject()
        writer.write("source", source)
        writer.write("positions", positions)
        writer.endObject()
    }
}

extension MouseMoveEventData.Position: JSONStreamWritable {
    func writeJSON(to writer: JSONWriter) {
        writer.beginObject()
        writer.write("x", x)
        writer.write("y", y)
        writer.writeIfPresent("id", id)
        writer.write("timeOffset", timeOffset)
        writer.endObject()
    }
}
