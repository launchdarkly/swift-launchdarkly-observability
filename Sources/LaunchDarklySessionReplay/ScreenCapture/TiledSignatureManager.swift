import UIKit
import CoreGraphics
import CommonCrypto

struct ImageSignature: Hashable {
    let rows: Int
    let columns: Int
    let tileWidth: Int
    let tileHeight: Int
    let tiledSignatures: [TiledSignature]
}

struct TiledSignature: Hashable {
    let hash: [UInt8]
}

final class TiledSignatureManager {
    func compute(image: UIImage) -> ImageSignature? {
        guard let image = image.cgImage else { return nil }
        let width = image.width
        let height = image.height
        let tileWidth = nearestDivisor(value: width, preferred: 64, range: 53...75)
        let tileHeight = nearestDivisor(value: height, preferred: 44, range: 44...50)
        let columns = (width + tileWidth - 1) / tileWidth
        let rows = (height + tileHeight - 1) / tileHeight
        
        guard let data = image.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return nil }
        
        let bytesPerRow = image.bytesPerRow
        var tiledSignatures: [TiledSignature] = []
        tiledSignatures.reserveCapacity(columns * rows)
        
        for row in 0..<rows {
            let startY = row * tileHeight
            let endY = min(startY + tileHeight, height)
            
            for column in 0..<columns {
                let startX = column * tileWidth
                let endX = min(startX + tileWidth, width)
                let signature = tileHash(ptr: ptr, startX: startX, startY: startY, endX: endX, endY: endY, bytesPerRow: bytesPerRow)
                tiledSignatures.append(signature)
            }
        }
        
        return ImageSignature(rows: rows, columns: columns, tileWidth: tileWidth, tileHeight: tileHeight, tiledSignatures: tiledSignatures)
    }
    
    @inline(__always)
    func tileHash(ptr: UnsafePointer<UInt8>, startX: Int, startY: Int, endX: Int, endY: Int, bytesPerRow: Int) -> TiledSignature {
        var hasher = CC_SHA256_CTX()
        CC_SHA256_Init(&hasher)
        
        for row in startY..<endY {
            let offset = startX * 4 + row * bytesPerRow
            CC_SHA256_Update(&hasher, ptr + offset, CC_LONG(endX - startX) * 4)
        }
        
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&hash, &hasher)
        return TiledSignature(hash: hash)
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
        
        for (i, tile) in tiledSignatures.enumerated() where tile != other.tiledSignatures[i] {
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

