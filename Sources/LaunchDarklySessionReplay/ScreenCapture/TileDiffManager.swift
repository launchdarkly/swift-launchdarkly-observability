import Foundation
import UIKit

public struct CapturedFrame {
    public struct CapturedImage {
        public let image: UIImage
        public let rect: CGRect
    }
    
    public let capturedImages: [CapturedImage]
    public let scale: CGFloat
    public let originalSize: CGSize
    public let timestamp: TimeInterval
    public let orientation: Int
    public let isKeyframe: Bool
    
    /// Composites all captured images into a single UIImage by drawing each at its rect.
    public func wholeImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: originalSize, format: format)
        return renderer.image { _ in
            for capturedImage in capturedImages {
                capturedImage.image.draw(in: capturedImage.rect)
            }
        }
    }
}

final class TileDiffManager {
    private let tiledSignatureManager = TiledSignatureManager()
    private let transferMethod: SessionReplayOptions.TransferMethod
    private let scale: CGFloat
    private var previousSignature: ImageSignature?
    private var incrementalSnapshots = 0
    private let signatureLock = NSLock()

    init(transferMethod: SessionReplayOptions.TransferMethod, scale: CGFloat) {
        self.transferMethod = transferMethod
        self.scale = scale
    }

    func computeDiffCapture(frame: RawCapturedFrame) -> CapturedFrame? {
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
        if case .drawTiles(let frameWindow) = transferMethod {
            incrementalSnapshots = (incrementalSnapshots + 1) % frameWindow
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
                width: min(frame.image.size.width, diffRect.width),
                height: min(frame.image.size.height, diffRect.height)
            )
            guard let cropped = frame.image.cgImage?.cropping(to: finalRect) else {
                return nil
            }
            finalImage = UIImage(cgImage: cropped)
        }

        let capturedFrame = CapturedFrame(
            capturedImages: [CapturedFrame.CapturedImage(image: finalImage, rect: finalRect)],
            scale: scale,
            originalSize: frame.image.size,
            timestamp: frame.timestamp,
            orientation: frame.orientation,
            isKeyframe: isKeyframe
        )
        return capturedFrame
    }
}
