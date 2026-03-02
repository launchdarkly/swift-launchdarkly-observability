#if canImport(UIKit)

import Foundation
import OSLog
import LaunchDarklyObservability

public final class BenchmarkExecutor {
    public typealias CompressionResult = (
        compression: SessionReplayOptions.CompressionMethod,
        bytes: Int,
        executionTime: TimeInterval
    )

    private static let compressionMethods: [SessionReplayOptions.CompressionMethod] = [
        .screenImage,
        .overlayTiles(layers: 15, backtracking: false),
        .overlayTiles(layers: 15, backtracking: true),
    ]

    public init() {}

    public func compression(framesDirectory: URL, runs: Int = 1) async -> [CompressionResult] {
        let frames: [RawFrame]
        do {
            let reader = try RawFrameReader(directory: framesDirectory)
            frames = Array(reader)
        } catch {
            print("BenchmarkExecutor: failed to read frames – \(error)")
            return []
        }

        var results = [CompressionResult]()
        let runCount = max(1, runs)

        for method in Self.compressionMethods {
            var bytes = 0
            var executionTime: TimeInterval = 0

            for _ in 0..<runCount {
                let runResult = await runCompression(method, frames: frames)
                bytes = runResult.bytes
                executionTime += runResult.executionTime
            }

            results.append((compression: method, bytes: bytes, executionTime: executionTime))
        }

        return results
    }

    private func runCompression(_ method: SessionReplayOptions.CompressionMethod, frames: [RawFrame]) async -> (bytes: Int, executionTime: TimeInterval) {
        let exportDiffManager = ExportDiffManager(compression: method, scale: 1.0)
        let eventGenerator = RRWebEventGenerator(log: OSLog.default, title: "Benchmark", method: method)
        let encoder = JSONEncoder()
        var bytes = 0

        let start = CFAbsoluteTimeGetCurrent()

        for frame in frames {
            guard let exportFrame = exportDiffManager.exportFrame(from: frame) else {
                continue
            }

            let item = EventQueueItem(payload: ImageItemPayload(exportFrame: exportFrame))
            let events = await eventGenerator.generateEvents(items: [item])

            if let data = try? encoder.encode(events) {
                bytes += data.count
            }
        }

        return (bytes: bytes, executionTime: CFAbsoluteTimeGetCurrent() - start)
    }
}

#endif
