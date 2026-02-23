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
        var results = [CompressionResult]()
        let runCount = max(1, runs)

        for method in Self.compressionMethods {
            var bytes = 0
            var executionTime: TimeInterval = 0

            for _ in 0..<runCount {
                let runResult = await runCompression(method, framesDirectory: framesDirectory)
                bytes = runResult.bytes
                executionTime += runResult.executionTime
            }

            results.append((compression: method, bytes: bytes, executionTime: executionTime))
        }

        return results
    }

    private func runCompression(_ method: SessionReplayOptions.CompressionMethod, framesDirectory: URL) async -> (bytes: Int, executionTime: TimeInterval) {
        let start = CFAbsoluteTimeGetCurrent()
        var bytes = 0
        do {
            let reader = try RawFrameReader(directory: framesDirectory)
            let exportDiffManager = ExportDiffManager(compression: method, scale: 1.0)
            let eventGenerator = RRWebEventGenerator(log: OSLog.default, title: "Benchmark", method: method)
            let encoder = JSONEncoder()

            for frame in reader {
                guard let exportFrame = exportDiffManager.exportFrame(from: frame) else {
                    continue
                }

                let item = EventQueueItem(payload: ImageItemPayload(exportFrame: exportFrame))
                let events = await eventGenerator.generateEvents(items: [item])

                if let data = try? encoder.encode(events) {
                    bytes += data.count
                }
            }
        } catch {
            print("BenchmarkExecutor: failed to read frames – \(error)")
        }

        return (bytes: bytes, executionTime: CFAbsoluteTimeGetCurrent() - start)
    }
}

#endif
