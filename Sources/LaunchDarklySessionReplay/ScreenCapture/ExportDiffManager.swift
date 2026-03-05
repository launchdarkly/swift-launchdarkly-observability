import Foundation
import UIKit


final class ExportDiffManager {
    private let tileDiffManager: TileDiffManager
    private var currentImages = [ExportFrame.RemoveImage]()
    private var currentImagesIndex: [ImageSignature: Int] = [:]
    private let format = ExportFormat.jpeg(quality: 0.3)
    private let compression: SessionReplayOptions.CompressionMethod
    private let lock = NSLock()
    private var keyFrameId: Int = 0
    
    init(compression: SessionReplayOptions.CompressionMethod, scale: CGFloat) {
        self.compression = compression
        self.tileDiffManager = TileDiffManager(compression: compression, scale: scale)
    }

    func exportFrame(from frame: RawFrame, onTiledFrameComputed: (() -> Void)? = nil) -> ExportFrame? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let capturedFrame = tileDiffManager.computeTiledFrame(frame: frame) else {
            return nil
        }
        onTiledFrameComputed?()
        return exportTiledFrame(capturedFrame)
    }

    private func exportTiledFrame(_ tiledFrame: TiledFrame) -> ExportFrame? {
        var adds = [ExportFrame.AddImage]()
        var removes = [ExportFrame.RemoveImage]()
        
        if tiledFrame.isKeyframe {
            removes = currentImages
            currentImages.removeAll(keepingCapacity: true)
            currentImagesIndex.removeAll()
            keyFrameId += 1
        }
        
        if let signature = tiledFrame.imageSignature,
           case .overlayTiles(_, true) = compression,
           let lastKeyNodeIdx = currentImagesIndex[signature],
           lastKeyNodeIdx < currentImages.count {
            removes = Array(currentImages[(lastKeyNodeIdx + 1)...])
            currentImages = Array(currentImages[0...lastKeyNodeIdx])
            currentImagesIndex = currentImagesIndex.filter { $0.value <= lastKeyNodeIdx }
        } else {
            for tile in tiledFrame.tiles {
                let imageSignature = tiledFrame.imageSignature
                guard let addImage = tile.image.asExportedImage(format: format, rect: tile.rect, imageSignature: imageSignature) else {
                    return nil
                }
                adds.append(addImage)
                if let imageSignature {
                    currentImages.append(ExportFrame.RemoveImage(keyFrameId: keyFrameId, imageSignature: imageSignature))
                }
            }
            if let signature = tiledFrame.imageSignature {
                currentImagesIndex[signature] = currentImages.count - 1
            }
        }
        
        guard !adds.isEmpty || !removes.isEmpty else { return nil }

        return ExportFrame(keyFrameId: keyFrameId,
                           addImages: adds,
                           removeImages: removes,
                           originalSize: tiledFrame.originalSize,
                           scale: tiledFrame.scale,
                           format: format,
                           timestamp: tiledFrame.timestamp,
                           orientation: tiledFrame.orientation,
                           isKeyframe: tiledFrame.isKeyframe,
                           imageSignature: tiledFrame.imageSignature)
    }
}
