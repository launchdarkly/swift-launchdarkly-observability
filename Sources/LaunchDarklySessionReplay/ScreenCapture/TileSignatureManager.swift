import UIKit
@_exported import SessionReplayHotPath

extension TileSignatureManager {
    func compute(image: UIImage) -> ImageSignature? {
        guard let cgImage = image.cgImage else { return nil }
        return compute(cgImage: cgImage)
    }
}
