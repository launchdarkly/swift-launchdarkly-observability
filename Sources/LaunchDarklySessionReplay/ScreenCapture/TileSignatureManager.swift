import UIKit
import CoreGraphics
import SessionReplayC

struct ImageSignature: Hashable {
    let rows: Int
    let columns: Int
    let tileWidth: Int
    let tileHeight: Int
    let tileSignatures: [TileSignature]
    private let _hashValue: Int

    init(rows: Int, columns: Int, tileWidth: Int, tileHeight: Int, tileSignatures: [TileSignature]) {
        self.init(
            rows: rows, columns: columns,
            tileWidth: tileWidth, tileHeight: tileHeight,
            tileSignatures: tileSignatures,
            tileAccHash: Self._accumulateHash(tileSignatures)
        )
    }

    init(rows: Int, columns: Int, tileWidth: Int, tileHeight: Int, tileSignatures: [TileSignature], tileAccHash: Int) {
        self.rows = rows
        self.columns = columns
        self.tileWidth = tileWidth
        self.tileHeight = tileHeight
        self.tileSignatures = tileSignatures

        var hasher = Hasher()
        hasher.combine(rows)
        hasher.combine(columns)
        hasher.combine(tileWidth)
        hasher.combine(tileHeight)
        hasher.combine(tileAccHash)
        self._hashValue = hasher.finalize()
    }

    @inline(__always)
    static func _accumulateTile(_ acc: Int, _ sig: TileSignature) -> Int {
        (acc &* 31) &+ Int(truncatingIfNeeded: sig.hashLo ^ sig.hashHi)
    }

    private static func _accumulateHash(_ tiles: [TileSignature]) -> Int {
        var acc = 0
        for sig in tiles { acc = _accumulateTile(acc, sig) }
        return acc
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(_hashValue)
    }

    static func == (lhs: ImageSignature, rhs: ImageSignature) -> Bool {
        lhs._hashValue == rhs._hashValue &&
        lhs.rows == rhs.rows &&
        lhs.columns == rhs.columns &&
        lhs.tileWidth == rhs.tileWidth &&
        lhs.tileHeight == rhs.tileHeight &&
        lhs.tileSignatures == rhs.tileSignatures
    }
}

struct TileSignature: Hashable {
    let hashLo: Int64
    let hashHi: Int64
}

final class TileSignatureManager {
    func compute(image: UIImage) -> ImageSignature? {
        guard let cgImage = image.cgImage else { return nil }
        return compute(cgImage: cgImage)
    }

    func compute(cgImage: CGImage) -> ImageSignature? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        let tileWidth = nearestDivisor(value: width, preferred: 64, range: 60...79)
        let tileHeight = nearestDivisor(value: height, preferred: 22, range: 22...44)
        let columns = (width + tileWidth - 1) / tileWidth
        let rows = (height + tileHeight - 1) / tileHeight

        guard let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return nil }

        let bytesPerRow = cgImage.bytesPerRow
        let totalTiles = columns * rows
        let raw = UnsafeRawPointer(ptr)

        var tileAccHash = 0
        let tileSignatures = [TileSignature](unsafeUninitializedCapacity: totalTiles) { buffer, count in
            var idx = 0
            for row in 0..<rows {
                let startY = row * tileHeight
                let endY = min(startY + tileHeight, height)

                for column in 0..<columns {
                    let startX = column * tileWidth
                    let endX = min(startX + tileWidth, width)
                    let sig = Self.tileHash(raw: raw, startX: startX, startY: startY, endX: endX, endY: endY, bytesPerRow: bytesPerRow)
                    buffer[idx] = sig
                    tileAccHash = ImageSignature._accumulateTile(tileAccHash, sig)
                    idx += 1
                }
            }
            count = totalTiles
        }

        return ImageSignature(rows: rows, columns: columns, tileWidth: tileWidth, tileHeight: tileHeight, tileSignatures: tileSignatures, tileAccHash: tileAccHash)
    }

    @inline(__always)
    private static func tileHash(raw: UnsafeRawPointer, startX: Int, startY: Int, endX: Int, endY: Int, bytesPerRow: Int) -> TileSignature {
        let result = tile_hash(raw,
                               Int32(startX), Int32(startY),
                               Int32(endX),   Int32(endY),
                               Int32(bytesPerRow))
        return TileSignature(hashLo: result.hashLo, hashHi: result.hashHi)
    }

    private func nearestDivisor(value: Int, preferred: Int, range: ClosedRange<Int>) -> Int {
        guard value > 0 else {
            return preferred
        }

        func isDivisor(_ candidate: Int) -> Bool {
            candidate > 0 && value.isMultiple(of: candidate)
        }

        if range.contains(preferred), isDivisor(preferred) {
            return preferred
        }

        let maxDistance = max(abs(range.lowerBound - preferred), abs(range.upperBound - preferred))
        guard maxDistance > 0 else {
            return preferred
        }

        for offset in 1...maxDistance {
            let positiveCandidate = preferred + offset
            if range.contains(positiveCandidate), isDivisor(positiveCandidate) {
                return positiveCandidate
            }

            let negativeCandidate = preferred - offset
            if range.contains(negativeCandidate), isDivisor(negativeCandidate) {
                return negativeCandidate
            }
        }

        return preferred
    }
}

extension ImageSignature {
    func diffRectangle(other: ImageSignature?) -> CGRect? {
        guard let other else {
            return CGRect(x: 0,
                          y: 0,
                          width: columns * tileWidth,
                          height: rows * tileHeight)
        }

        guard rows == other.rows, columns == other.columns, tileWidth == other.tileWidth, tileHeight == other.tileHeight else {
            return CGRect(x: 0,
                          y: 0,
                          width: columns * tileWidth,
                          height: rows * tileHeight)
        }

        var minRow = Int.max
        var maxRow = Int.min
        var minColumn = Int.max
        var maxColumn = Int.min

        for (i, tile) in tileSignatures.enumerated() where tile != other.tileSignatures[i] {
            let row = i / columns
            let col = i % columns
            minRow = min(minRow, row)
            maxRow = max(maxRow, row)
            minColumn = min(minColumn, col)
            maxColumn = max(maxColumn, col)
        }

        guard minRow != Int.max else {
            return nil
        }

        return CGRect(x: minColumn * tileWidth,
                      y: minRow * tileHeight,
                      width: (maxColumn - minColumn + 1) * tileWidth,
                      height: (maxRow - minRow + 1) * tileHeight)
    }
}
