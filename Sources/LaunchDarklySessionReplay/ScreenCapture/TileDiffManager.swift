import Foundation
import UIKit

struct TiledFrame {
    struct Tile {
        let image: UIImage
        let rect: CGRect
    }
    
    let id: Int
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
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: originalSize, format: format)
        return renderer.image { _ in
            for capturedImage in tiles {
                capturedImage.image.draw(in: capturedImage.rect)
            }
        }
    }
}

final class TileDiffManager {
    private let tileSignatureManager = TileSignatureManager()
    private let compression: SessionReplayOptions.CompressionMethod
    private let scale: CGFloat
    private var previousSignature: ImageSignature?
    private var incrementalSnapshots = 0
    private var frameId = 0

    init(compression: SessionReplayOptions.CompressionMethod, scale: CGFloat) {
        self.compression = compression
        self.scale = scale
    }

    func computeTiledFrame(frame: RawFrame) -> TiledFrame? {
        guard let imageSignature = self.tileSignatureManager.compute(image: frame.image) else {
            return nil
        }

        frameId += 1
        guard let diffRect = imageSignature.diffRectangle(other: previousSignature) else {
            return nil
        }
        previousSignature = imageSignature

        // `diffRect` and the tile layout are expressed in pixels (the signature is
        // computed from the CGImage), whereas the exported tile rects and
        // `originalSize` the player lays tiles out in are in points. These two spaces
        // only coincide at `scale == 1`; for `scale > 1` keep all crop math in pixels
        // and convert the exported rect back to points using `scale`.
        let pixelWidth = CGFloat(frame.image.cgImage?.width ?? Int(frame.image.size.width * scale))
        let pixelHeight = CGFloat(frame.image.cgImage?.height ?? Int(frame.image.size.height * scale))

        let isKeyframe: Bool
        if case .overlayTiles(let layers, _) = compression, layers > 0 {
            incrementalSnapshots = (incrementalSnapshots + 1) % layers
            if incrementalSnapshots == 0 {
                isKeyframe = true
            } else {
                let needWholeScreen = (diffRect.size.width >= pixelWidth && diffRect.size.height >= pixelHeight)
                if needWholeScreen {
                    incrementalSnapshots = 0
                }
                isKeyframe = needWholeScreen
            }
        } else {
            isKeyframe = true
        }

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
            // Crop in pixel space — `CGImage.cropping(to:)` operates on pixels.
            let cropRect = CGRect(
                x: diffRect.minX,
                y: diffRect.minY,
                width: min(pixelWidth - diffRect.minX, diffRect.width),
                height: min(pixelHeight - diffRect.minY, diffRect.height)
            )
            guard let cropped = frame.image.cgImage?.cropping(to: cropRect) else {
                return nil
            }
            finalImage = UIImage(cgImage: cropped)
            // Convert back to point space for the exported tile rect so it matches the
            // point-based `originalSize` the player positions/sizes tiles against. The
            // cropped image keeps its full pixel resolution; the player downscales it
            // into the point-sized tile.
            let pointScale = scale > 0 ? scale : 1.0
            finalRect = CGRect(
                x: cropRect.minX / pointScale,
                y: cropRect.minY / pointScale,
                width: cropRect.width / pointScale,
                height: cropRect.height / pointScale
            )
        }

        let imageSignatureForTransfer: ImageSignature? = {
            if case .overlayTiles = compression {
                return imageSignature
            }
            return nil
        }()

        let capturedFrame = TiledFrame(
            id: frameId,
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
