#if canImport(UIKit)

import Foundation
import OSLog
import UIKit
import LaunchDarklyObservability

public final class CompressionBenchmarkRunner {
    public typealias Result = (bytes: Int, captureTime: TimeInterval, totalTime: TimeInterval)

    public init() {}

    public func run(method: SessionReplayOptions.CompressionMethod, frames: [RawFrame]) async -> Result {
        let exportDiffManager = ExportDiffManager(compression: method, scale: 1.0)
        let eventGenerator = RRWebEventGenerator(log: OSLog.default, title: "Benchmark", method: method)
        let encoder = JSONEncoder()
        var bytes = 0
        var captureTime: TimeInterval = 0

        let start = CFAbsoluteTimeGetCurrent()

        for frame in frames {
            let captureStart = CFAbsoluteTimeGetCurrent()
            let exportFrame = exportDiffManager.exportFrame(from: frame)
            captureTime += CFAbsoluteTimeGetCurrent() - captureStart
            guard let exportFrame else {
                continue
            }

            let item = EventQueueItem(payload: ImageItemPayload(exportFrame: exportFrame, sessionId: ""))
            let events = await eventGenerator.generateEvents(items: [item])

            if let data = try? encoder.encode(events) {
                bytes += data.count
            }
        }

        return (bytes: bytes, captureTime: captureTime, totalTime: CFAbsoluteTimeGetCurrent() - start)
    }
}

#endif
