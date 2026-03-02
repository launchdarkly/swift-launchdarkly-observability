#if canImport(UIKit)

import Foundation
import OSLog
import LaunchDarklyObservability

public final class BenchmarkExecutor {
    public typealias CompressionResult = (
        compression: SessionReplayOptions.CompressionMethod,
        bytes: Int,
        captureTime: TimeInterval,
        totalTime: TimeInterval
    )

    private static let compressionMethods: [SessionReplayOptions.CompressionMethod] = [
        .screenImage,
        .overlayTiles(layers: 15, backtracking: false),
        .overlayTiles(layers: 15, backtracking: true),
    ]

    public init() {}

    public func compression(framesDirectory: URL, runs: Int = 1) async throws -> [CompressionResult] {
        let reader = try RawFrameReader(directory: framesDirectory)
        let frames = Array(reader)

        var results = [CompressionResult]()
        let runCount = max(1, runs)

        for method in Self.compressionMethods {
            var bytes = 0
            var captureTime: TimeInterval = 0
            var totalTime: TimeInterval = 0

            for _ in 0..<runCount {
                let runResult = await runCompression(method, frames: frames)
                bytes = runResult.bytes
                captureTime += runResult.captureTime
                totalTime += runResult.totalTime
            }

            results.append((compression: method, bytes: bytes, captureTime: captureTime, totalTime: totalTime))
        }

        return results
    }

    private func runCompression(_ method: SessionReplayOptions.CompressionMethod, frames: [RawFrame]) async -> (bytes: Int, captureTime: TimeInterval, totalTime: TimeInterval) {
        let exportDiffManager = ExportDiffManager(compression: method, scale: 1.0)
        let eventGenerator = RRWebEventGenerator(log: OSLog.default, title: "Benchmark", method: method)
        let encoder = JSONEncoder()
        var bytes = 0
        var captureTime: TimeInterval = 0

        let start = CFAbsoluteTimeGetCurrent()

        for frame in frames {
            let captureStart = CFAbsoluteTimeGetCurrent()
            guard let exportFrame = exportDiffManager.exportFrame(from: frame, onTiledFrameComputed: {
                captureTime += CFAbsoluteTimeGetCurrent() - captureStart
            }) else {
                continue
            }

            let item = EventQueueItem(payload: ImageItemPayload(exportFrame: exportFrame))
            let events = await eventGenerator.generateEvents(items: [item])

            if let data = try? encoder.encode(events) {
                bytes += data.count
            }
        }

        return (bytes: bytes, captureTime: captureTime, totalTime: CFAbsoluteTimeGetCurrent() - start)
    }
}

#endif
