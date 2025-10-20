import UIKit

private enum TouchConstants {
    static let tapMaxDistance = 12.0
    static let tapMaxMovementSquared: CGFloat = tapMaxDistance * tapMaxDistance
    static let tapMaxDuration: TimeInterval = 0.25
    
    static let swipeMinDistance: CGFloat = 72.0
    static let swipeMaxDuration: TimeInterval = 0.5
}

final class TouchIntepreter {
    struct Track {
        var start: TimeInterval
        var end: TimeInterval
        var startPoint: CGPoint
        var points: [TouchPoint]
        var target: TouchTarget?
    }
    
    private var tracks = [ObjectIdentifier: Track]()
    
    func process(touchSample: TouchSample, yield: UIInteractionYield) {
        switch touchSample.phase {
        case .began:
            let track = Track(start: touchSample.timestamp,
                              end: touchSample.timestamp,
                              startPoint: touchSample.location,
                              points: [TouchPoint(position: touchSample.location, timeOffset: 0)],
                              target: touchSample.target)
            tracks[touchSample.id] = track
            
            let downInteraction = UIInteraction(kind: .touchDown(touchSample.location),
                                                timestamp: touchSample.timestamp,
                                                target: touchSample.target)
            yield(downInteraction)
            
        case .moved:
            guard var track = tracks[touchSample.id] else { return }
            track.end = touchSample.timestamp
            track.target = touchSample.target
            
            let duration = touchSample.timestamp - track.start
            guard duration >= TouchConstants.tapMaxDuration else {
                return
            }
            
            let distance = squareDistance(from: track.startPoint, to: touchSample.location)
            guard distance >= TouchConstants.tapMaxDistance else {
                return
            }
            
            track.points.append(TouchPoint(position: touchSample.location, timeOffset: duration))
            tracks[touchSample.id] = track
            
        case .ended, .cancelled:
            let upInteraction = UIInteraction(kind: .touchUp(touchSample.location),
                                              timestamp: touchSample.timestamp,
                                              target: touchSample.target)
            yield(upInteraction)
            
            guard let track = tracks.removeValue(forKey: touchSample.id), track.points.isNotEmpty else { return }
            
            let moveInteraction = UIInteraction(kind: .touchPath(points: track.points),
                                                timestamp: touchSample.timestamp,
                                                target: touchSample.target)
            yield(moveInteraction)
        }
    }
    
    func squareDistance(from: CGPoint, to: CGPoint) -> CGFloat {
        let dx = from.x - to.x
        let dy = from.y - to.y
        return dx * dx + dy * dy
    }
    
}
