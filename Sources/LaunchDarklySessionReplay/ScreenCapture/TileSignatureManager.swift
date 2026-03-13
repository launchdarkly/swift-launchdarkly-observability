import UIKit
#if !LD_COCOAPODS
import SessionReplayC
#endif

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
