import Foundation
import UIKit


final class ExportDiffManager {
    private let tileDiffManager: TileDiffManager
    private var currentImages = [ExportFrame.RemoveImage]()
    private var currentImagesIndex: [ImageSignature: Int] = [:]
    private let format = ExportFormat.jpeg(quality: 0.3)
    private let compression: SessionReplayOptions.CompressionMethod
    private let signatureLock = NSLock()
    private var keyFrameId: Int = 0
    
    init(compression: SessionReplayOptions.CompressionMethod, scale: CGFloat) {
        self.compression = compression
        self.tileDiffManager = TileDiffManager(compression: compression, scale: scale)
    }

    func exportFrame(from frame: RawFrame) -> ExportFrame? {
        signatureLock.lock()
        defer { signatureLock.unlock() }
        
        guard let capturedFrame = tileDiffManager.computeDiffCapture(frame: frame) else {
            return nil
        }
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
           let lastKeyNodeIdx = currentImagesIndex[signature],
           lastKeyNodeIdx < currentImages.count {
            removes = Array(currentImages[(lastKeyNodeIdx + 1)...])
            currentImages = Array(currentImages[0...lastKeyNodeIdx])
            currentImagesIndex = currentImagesIndex.filter { $0.value > lastKeyNodeIdx }
        } else {
            for (tileIdx, tile) in tiledFrame.tiles.enumerated() {
                var tiledSignature: TiledSignature?
                if let signature = tiledFrame.imageSignature {
                    tiledSignature = signature.tiledSignatures[tileIdx]
                }
                guard let addImage = tile.image.asExportedImage(format: format, rect: tile.rect, tiledSignature: tiledSignature) else {
                    return nil
                }
                adds.append(addImage)
                if let tiledSignature {
                    currentImages.append(ExportFrame.RemoveImage(keyFrameId: keyFrameId, tiledSignature: tiledSignature))
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
