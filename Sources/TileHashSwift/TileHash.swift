public struct TileHashResult {
    public let hashLo: Int64
    public let hashHi: Int64
}

public func tileHash(ptr: UnsafePointer<UInt8>, startX: Int, startY: Int, endX: Int, endY: Int, bytesPerRow: Int) -> TileHashResult {
    var hashLo: Int64 = 5_163_949_831_757_626_579
    var hashHi: Int64 = 4_657_936_482_115_123_397
    let primeLo: Int64 = 1_238_197_591_667_094_937
    let primeHi: Int64 = 1_700_294_137_212_722_571

    let raw = UnsafeRawPointer(ptr)
    let pixelCount = endX &- startX
    let pairCount = pixelCount >> 1
    let hasTrailingPixel = pixelCount & 1 != 0

    for y in startY..<endY {
        var p = raw + (y &* bytesPerRow &+ startX &* 4)

        for _ in 0..<pairCount {
            let v = Int64(bitPattern: p.loadUnaligned(as: UInt64.self))
            hashLo = (hashLo ^ v) &* primeLo
            hashHi = (hashHi ^ v) &* primeHi
            p += 8
        }

        if hasTrailingPixel {
            let v = Int64(p.loadUnaligned(as: UInt32.self))
            hashLo = (hashLo ^ v) &* primeLo
            hashHi = (hashHi ^ v) &* primeHi
        }
    }

    return TileHashResult(hashLo: hashLo, hashHi: hashHi)
}
