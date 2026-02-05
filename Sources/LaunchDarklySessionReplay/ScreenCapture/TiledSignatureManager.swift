import UIKit
import CoreGraphics
import CommonCrypto

struct ImageSignature: Hashable {
    let rows: Int
    let columns: Int
    let tileSize: Int
    let tiledSignatures: [TiledSignature]
}

struct TiledSignature: Hashable {
    let hash: [UInt8]
}

final class TiledSignatureManager {
    let tileSize: Int = 64
    
    func compute(image: UIImage) -> ImageSignature? {
        guard let image = image.cgImage else { return nil }
        let width = image.width
        let height = image.height
        let columns = (width + tileSize - 1) / tileSize
        let rows = (height + tileSize - 1) / tileSize
        
        guard let data = image.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return nil }
        
        let bytesPerRow = image.bytesPerRow
        var tiledSignatures: [TiledSignature] = []
        tiledSignatures.reserveCapacity(columns * rows)
        
        for row in 0..<rows {
            let startY = row * tileSize
            let endY = min(startY + tileSize, height)
            
            for column in 0..<columns {
                let startX = column * tileSize
                let endX = min(startX + tileSize, width)
                let signature = tileHash(ptr: ptr, startX: startX, startY: startY, endX: endX, endY: endY, bytesPerRow: bytesPerRow)
                tiledSignatures.append(signature)
            }
        }
        
        return ImageSignature(rows: rows, columns: columns, tileSize: tileSize, tiledSignatures: tiledSignatures)
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
}

extension ImageSignature {
    // returns nil if signatures equal
    func diffRectangle(other: ImageSignature?) -> CGRect? {
        guard let other else {
            return CGRect(x: 0,
                          y: 0,
                          width: columns * tileSize,
                          height: rows * tileSize)
        }
        
        guard rows == other.rows, columns == other.columns else {
            return nil
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
        
        return CGRect(x: minColumn * tileSize,
                      y: minRow * tileSize,
                      width: (maxColumn - minColumn + 1) * tileSize,
                      height: (maxRow - minRow + 1) * tileSize)
    }
}
