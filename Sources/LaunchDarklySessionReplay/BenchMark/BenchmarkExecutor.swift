#if canImport(UIKit)

import Foundation
import OSLog
import CryptoKit
import UIKit
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

    public struct SignatureResult {
        public var elapsedTime: TimeInterval
        public var totalBytes: Int
        public var frameCount: Int
        public var signatureCount: Int
        public var tileSignaturesCount: Int
        public var strongSignatureCount: Int
        public var strongTileSignaturesCount: Int
    }

    public func signatureBenchmark(framesDirectory: URL) throws -> SignatureResult {
        let reader = try RawFrameReader(directory: framesDirectory)
        return signatureBenchmark(frames: Array(reader))
    }

    public func signatureBenchmark(benchmarkDirectory: URL) throws -> SignatureResult {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: benchmarkDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        let subdirs = contents.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        var allFrames = [RawFrame]()
        for subdir in subdirs {
            let csvURL = subdir.appendingPathComponent("frames.csv")
            guard fm.fileExists(atPath: csvURL.path) else { continue }
            let reader = try RawFrameReader(directory: subdir)
            allFrames.append(contentsOf: reader)
        }
        guard !allFrames.isEmpty else {
            return SignatureResult(elapsedTime: 0, totalBytes: 0, frameCount: 0,
                                  signatureCount: 0, tileSignaturesCount: 0,
                                  strongSignatureCount: 0, strongTileSignaturesCount: 0)
        }
        return signatureBenchmark(frames: allFrames)
    }

    private func signatureBenchmark(frames: [RawFrame]) -> SignatureResult {
        let manager = TileSignatureManager()
        let easyManager = EasyTileSignatureManager()
        var totalBytes = 0
        var signatures = Set<ImageSignature>()
        var tileSignatures = Set<TileSignature>()
        var strongSignatures = Set<ImageSignature>()
        var strongTileSignatures = Set<TileSignature>()

        for frame in frames {
            if let cgImage = frame.image.cgImage {
                totalBytes += cgImage.bytesPerRow * cgImage.height
            }
        }

        let start = CFAbsoluteTimeGetCurrent()
        for frame in frames {
            if let signature = manager.compute(image: frame.image) {
                signatures.insert(signature)
                tileSignatures.formUnion(signature.tileSignatures)
            }
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        for frame in frames {
            if let signature = easyManager.compute(image: frame.image) {
                strongSignatures.insert(signature)
                strongTileSignatures.formUnion(signature.tileSignatures)
            }
        }

        return SignatureResult(elapsedTime: elapsed,
                               totalBytes: totalBytes,
                               frameCount: frames.count,
                               signatureCount: signatures.count,
                               tileSignaturesCount: tileSignatures.count,
                               strongSignatureCount: strongSignatures.count,
                               strongTileSignaturesCount: strongTileSignatures.count)
    }
    
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
            let exportFrame = exportDiffManager.exportFrame(from: frame)
            captureTime += CFAbsoluteTimeGetCurrent() - captureStart
            guard let exportFrame else {
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

/// Reference implementation of `TileSignatureManager` that uses SHA-256
/// for tile hashing. Produces the same tile layout as the C implementation
/// but hashes each tile with a cryptographic function so the unique-count
/// can be compared against the fast version to detect hash collisions.
final class EasyTileSignatureManager {
    private static let tileWidth = 64

    func compute(image: UIImage) -> ImageSignature? {
        guard let cgImage = image.cgImage else { return nil }
        return compute(cgImage: cgImage)
    }

    func compute(cgImage: CGImage) -> ImageSignature? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        guard let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return nil }

        let tileW = Self.tileWidth
        let tileH = Self.nearestDivisor(value: height, preferred: 22, lo: 22, hi: 44)
        let columns = (width + tileW - 1) / tileW
        let rows = (height + tileH - 1) / tileH
        let bytesPerRow = cgImage.bytesPerRow

        var tileSignatures = [TileSignature]()
        tileSignatures.reserveCapacity(rows * columns)

        for row in 0..<rows {
            let startY = row * tileH
            let tileRows = min(tileH, height - startY)

            for col in 0..<columns {
                let startX = col * tileW
                let tilePixelWidth = min(tileW, width - startX)

                var sha = SHA256()
                for y in startY..<(startY + tileRows) {
                    let rowOffset = y * bytesPerRow + startX * 4
                    let byteCount = tilePixelWidth * 4
                    let buf = UnsafeBufferPointer(
                        start: ptr.advanced(by: rowOffset),
                        count: byteCount
                    )
                    sha.update(bufferPointer: UnsafeRawBufferPointer(buf))
                }

                let digest = sha.finalize()
                let sig = digest.withUnsafeBytes { raw in
                    TileSignature(
                        hashLo: raw.load(fromByteOffset: 0, as: Int64.self),
                        hashHi: raw.load(fromByteOffset: 8, as: Int64.self)
                    )
                }
                tileSignatures.append(sig)
            }
        }

        return ImageSignature(
            rows: rows, columns: columns,
            tileWidth: tileW, tileHeight: tileH,
            tileSignatures: tileSignatures
        )
    }

    private static func nearestDivisor(value: Int, preferred: Int, lo: Int, hi: Int) -> Int {
        guard value > 0 else { return preferred }
        if preferred >= lo, preferred <= hi, preferred > 0, value % preferred == 0 {
            return preferred
        }
        let maxDist = max(hi - preferred, preferred - lo)
        guard maxDist > 0 else { return preferred }
        for offset in 1...maxDist {
            let pos = preferred + offset
            if pos >= lo, pos <= hi, pos > 0, value % pos == 0 { return pos }
            let neg = preferred - offset
            if neg >= lo, neg <= hi, neg > 0, value % neg == 0 { return neg }
        }
        return preferred
    }
}

#endif
