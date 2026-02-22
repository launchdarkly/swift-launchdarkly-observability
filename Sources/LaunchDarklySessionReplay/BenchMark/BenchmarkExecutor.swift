#if canImport(UIKit)

import Foundation
import OSLog
import LaunchDarklyObservability

public final class BenchmarkExecutor {
    public typealias CompressionResult = (compression: SessionReplayOptions.CompressionMethod, bytes: Int)

    private static let compressionMethods: [SessionReplayOptions.CompressionMethod] = [
        .screenImage,
        .overlayTiles(layers: 15, backtracking: false),
        .overlayTiles(layers: 15, backtracking: true),
    ]

    public init() {}

    public func compression(framesDirectory: URL) async -> [CompressionResult] {
        var results = [CompressionResult]()

        for method in Self.compressionMethods {
            let bytes = await runCompression(method, framesDirectory: framesDirectory)
            results.append((compression: method, bytes: bytes))
        }

        return results
    }

    private func runCompression(_ method: SessionReplayOptions.CompressionMethod, framesDirectory: URL) async -> Int {
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

        return bytes
    }
}

#endif
