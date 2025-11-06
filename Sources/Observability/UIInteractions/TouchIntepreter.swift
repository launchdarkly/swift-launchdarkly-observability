import UIKit

private enum TouchConstants {
    static let tapMaxDistance = 12.0
    static let tapMaxDistanceSquared: CGFloat = tapMaxDistance * tapMaxDistance
    static let touchMoveMaxDuration: TimeInterval = 0.11
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
    
    var id: Int = 100
    var incrementingId: Int {
        // TODO: implement multifinger swipe with it
        defer { id += 1 }
        return id
    }
    
    func process(touchSample: TouchSample, yield: TouchInteractionYield) {
        // UITouch and UIEvent use time based on systemUptime getting and we needed adjustment for proper time
        let uptimeDifference = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        switch touchSample.phase {
        case .began:
            let track = Track(start: touchSample.timestamp,
                              end: touchSample.timestamp,
                              startPoint: touchSample.location,
                              points: [TouchPoint(position: touchSample.location, timestamp: touchSample.timestamp + uptimeDifference)],
                              target: touchSample.target)
            tracks[touchSample.id] = track
            
            let downInteraction = TouchInteraction(id: incrementingId,
                                                   kind: .touchDown(touchSample.location),
                                                   startTimestamp: touchSample.timestamp + uptimeDifference,
                                                   timestamp: touchSample.timestamp + uptimeDifference,
                                                   target: touchSample.target)
            yield(downInteraction)
            
        case .moved:
            guard var track = tracks[touchSample.id] else { return }
            track.end = touchSample.timestamp
            track.target = touchSample.target
            
            let previousTimestamp = (track.points.last?.timestamp ?? track.start)
            let duration = touchSample.timestamp + uptimeDifference - previousTimestamp
            guard duration >= TouchConstants.touchMoveMaxDuration else {
                return
            }
            
            let distance = squaredDistance(from: track.startPoint, to: touchSample.location)
            guard distance >= TouchConstants.tapMaxDistanceSquared else {
                return
            }
            
            track.points.append(TouchPoint(position: touchSample.location, timestamp: touchSample.timestamp + uptimeDifference))
            tracks[touchSample.id] = track
            
            let trackDuration = track.end - track.start
            if trackDuration > 0.9 {
                // flush movements of long touch path do not have dead time in the replay player
                flushMovements(touchSample: touchSample, uptimeDifference: uptimeDifference, startTimestamp: track.start, yield: yield)
            }
            
        case .ended, .cancelled:
            // touchUp
            let startTimestamp = tracks[touchSample.id]?.start ?? touchSample.timestamp
            let upInteraction = TouchInteraction(id: incrementingId,
                                                 kind: .touchUp(touchSample.location),
                                                 startTimestamp: startTimestamp + uptimeDifference,
                                                 timestamp: touchSample.timestamp + uptimeDifference,
                                                 target: touchSample.target)
            yield(upInteraction)
            
            // touchPath
            guard let track = tracks.removeValue(forKey: touchSample.id), track.points.isNotEmpty else { return }
            
            let moveInteraction = TouchInteraction(id: incrementingId,
                                                kind: .touchPath(points: track.points),
                                                startTimestamp: startTimestamp + uptimeDifference,
                                                timestamp: touchSample.timestamp + uptimeDifference,
                                                target: touchSample.target)
            yield(moveInteraction)
        }
    }
    
    func flushMovements(touchSample: TouchSample, uptimeDifference: TimeInterval, startTimestamp: TimeInterval, yield: TouchInteractionYield) {
        guard var track = tracks[touchSample.id], track.points.isNotEmpty else { return }
        
        let moveInteraction = TouchInteraction(id: incrementingId,
                                               kind: .touchPath(points: track.points),
                                               startTimestamp: startTimestamp + uptimeDifference,
                                               timestamp: touchSample.timestamp + uptimeDifference,
                                               target: touchSample.target)
        track.points.removeAll()
        tracks[touchSample.id] = track
        yield(moveInteraction)
    }

    func squaredDistance(from: CGPoint, to: CGPoint) -> CGFloat {
        let dx = from.x - to.x
        let dy = from.y - to.y
        return dx * dx + dy * dy
    }
}
