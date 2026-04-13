import CoreGraphics

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

extension ImageSignature {
    // returns null for equal images
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
