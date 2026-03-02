import UIKit
import CoreGraphics

struct ImageSignature: Hashable {
    let rows: Int
    let columns: Int
    let tileWidth: Int
    let tileHeight: Int
    let tileSignatures: [TileSignature]
}

struct TileSignature: Hashable {
    let hashLo: Int64
    let hashHi: Int64
}

final class TileSignatureManager {
    func compute(image: UIImage) -> ImageSignature? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let tileWidth = nearestDivisor(value: width, preferred: 64, range: 60...79)
        let tileHeight = nearestDivisor(value: height, preferred: 22, range: 22...44)
        let columns = (width + tileWidth - 1) / tileWidth
        let rows = (height + tileHeight - 1) / tileHeight
        
        guard let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return nil }
        
        let bytesPerRow = cgImage.bytesPerRow
        var tileSignatures: [TileSignature] = []
        tileSignatures.reserveCapacity(columns * rows)
        
        for row in 0..<rows {
            let startY = row * tileHeight
            let endY = min(startY + tileHeight, height)
            
            for column in 0..<columns {
                let startX = column * tileWidth
                let endX = min(startX + tileWidth, width)
                let signature = tileHash(ptr: ptr, startX: startX, startY: startY, endX: endX, endY: endY, bytesPerRow: bytesPerRow)
                tileSignatures.append(signature)
            }
        }
        
        return ImageSignature(rows: rows, columns: columns, tileWidth: tileWidth, tileHeight: tileHeight, tileSignatures: tileSignatures)
    }
    
    @inline(__always)
    func tileHash(ptr: UnsafePointer<UInt8>, startX: Int, startY: Int, endX: Int, endY: Int, bytesPerRow: Int) -> TileSignature {
        // Two independent 64-bit lanes to reduce collision probability vs single-lane hashing.
        var hashLo: Int64 = 5_163_949_831_757_626_579
        var hashHi: Int64 = 4_657_936_482_115_123_397
        let primeLo: Int64 = 1_238_197_591_667_094_937
        let primeHi: Int64 = 1_700_294_137_212_722_571

        for y in startY..<endY {
            let rowBase = y &* bytesPerRow
            for x in startX..<endX {
                let offset = rowBase &+ x &* 4
                let b0 = Int64(ptr[offset])
                let b1 = Int64(ptr[offset &+ 1])
                let b2 = Int64(ptr[offset &+ 2])
                let b3 = Int64(ptr[offset &+ 3])

                hashLo = (hashLo ^ b0) &* primeLo
                hashLo = (hashLo ^ b1) &* primeLo
                hashLo = (hashLo ^ b2) &* primeLo
                hashLo = (hashLo ^ b3) &* primeLo

                hashHi = (hashHi ^ b3) &* primeHi
                hashHi = (hashHi ^ b2) &* primeHi
                hashHi = (hashHi ^ b1) &* primeHi
                hashHi = (hashHi ^ b0) &* primeHi
            }
        }

        return TileSignature(hashLo: hashLo, hashHi: hashHi)
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
    // returns nil if signatures equal
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

