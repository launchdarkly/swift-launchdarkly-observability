import Foundation
import UIKit

struct TiledFrame {
    struct Tile {
        public let image: UIImage
        public let rect: CGRect
    }
    
    let tiles: [Tile]
    let scale: CGFloat
    let originalSize: CGSize
    let timestamp: TimeInterval
    let orientation: Int
    let isKeyframe: Bool
    let imageSignature: ImageSignature?
    
    /// Composites all captured images into a single UIImage by drawing each at its rect.
    func wholeImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: originalSize, format: format)
        return renderer.image { _ in
            for capturedImage in tiles {
                capturedImage.image.draw(in: capturedImage.rect)
            }
        }
    }
}

final class TileDiffManager {
    private let tiledSignatureManager = TiledSignatureManager()
    private let compression: SessionReplayOptions.CompressionMethod
    private let scale: CGFloat
    private var previousSignature: ImageSignature?
    private var incrementalSnapshots = 0
    private let signatureLock = NSLock()

    init(compression: SessionReplayOptions.CompressionMethod, scale: CGFloat) {
        self.compression = compression
        self.scale = scale
    }

    func computeDiffCapture(frame: RawCapturedFrame) -> TiledFrame? {
        guard let imageSignature = self.tiledSignatureManager.compute(image: frame.image) else {
            return nil
        }

        signatureLock.lock()

        guard let diffRect = imageSignature.diffRectangle(other: previousSignature) else {
            signatureLock.unlock()
            return nil
        }
        previousSignature = imageSignature

        let needWholeScreen = (diffRect.size.width >= frame.image.size.width && diffRect.size.height >= frame.image.size.height)
        let isKeyframe: Bool
        if case .overlayTiles(let layers) = compression, layers > 0 {
            incrementalSnapshots = (incrementalSnapshots + 1) % layers
            isKeyframe = needWholeScreen || incrementalSnapshots == 0
            if needWholeScreen {
                incrementalSnapshots = 0
            }
        } else {
            isKeyframe = true
        }

        signatureLock.unlock()

        let finalRect: CGRect
        let finalImage: UIImage

        if isKeyframe {
            finalImage = frame.image
            finalRect = CGRect(
                x: 0,
                y: 0,
                width: frame.image.size.width,
                height: frame.image.size.height
            )
        } else {
            finalRect = CGRect(
                x: diffRect.minX,
                y: diffRect.minY,
                width: min(frame.image.size.width - diffRect.minX, diffRect.width),
                height: min(frame.image.size.height - diffRect.minY, diffRect.height)
            )
            guard let cropped = frame.image.cgImage?.cropping(to: finalRect) else {
                return nil
            }
            finalImage = UIImage(cgImage: cropped)
        }

        let imageSignatureForTransfer: ImageSignature? = {
            if case .overlayTiles = compression {
                return imageSignature
            }
            return nil
        }()

        let capturedFrame = TiledFrame(
            tiles: [TiledFrame.Tile(image: finalImage, rect: finalRect)],
            scale: scale,
            originalSize: frame.image.size,
            timestamp: frame.timestamp,
            orientation: frame.orientation,
            isKeyframe: isKeyframe,
            imageSignature: imageSignatureForTransfer
        )
        return capturedFrame
    }
}
