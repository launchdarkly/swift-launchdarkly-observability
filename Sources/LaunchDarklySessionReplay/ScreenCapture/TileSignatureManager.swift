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
    private var cBuffer: UnsafeMutablePointer<TileHashResult>?
    private var cBufferCapacity = 0

    deinit {
        cBuffer?.deallocate()
    }

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

        let layout = tile_compute_layout(Int32(width), Int32(height))
        let rows = Int(layout.rows)
        let columns = Int(layout.columns)
        let totalTiles = rows * columns

        if totalTiles > cBufferCapacity {
            cBuffer?.deallocate()
            cBuffer = .allocate(capacity: totalTiles)
            cBufferCapacity = totalTiles
        }
        let buf = cBuffer!

        tile_compute_all(UnsafeRawPointer(ptr),
                         Int32(width), Int32(height),
                         Int32(cgImage.bytesPerRow),
                         layout,
                         buf)

        var tileAccHash = 0
        let tileSignatures = [TileSignature](unsafeUninitializedCapacity: totalTiles) { buffer, count in
            for i in 0..<totalTiles {
                let r = buf[i]
                let sig = TileSignature(hashLo: r.hashLo, hashHi: r.hashHi)
                buffer[i] = sig
                tileAccHash = ImageSignature._accumulateTile(tileAccHash, sig)
            }
            count = totalTiles
        }

        return ImageSignature(rows: rows, columns: columns,
                              tileWidth: Int(layout.tileWidth), tileHeight: Int(layout.tileHeight),
                              tileSignatures: tileSignatures, tileAccHash: tileAccHash)
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
