import Foundation
import UIKit

final class ExportDiffManager {
    private let tileDiffManager: TileDiffManager

    init(compression: SessionReplayOptions.CompressionMethod, scale: CGFloat) {
        self.tileDiffManager = TileDiffManager(compression: compression, scale: scale)
    }

    func exportFrame(from frame: RawFrame) -> ExportFrame? {
        guard let capturedFrame = tileDiffManager.computeDiffCapture(frame: frame) else {
            return nil
        }
        return exportTiledFrame(capturedFrame)
    }

    private func exportTiledFrame(_ capturedFrame: TiledFrame) -> ExportFrame? {
        let format = ExportFormat.jpeg(quality: 0.3)
        var exportedFrames = [ExportFrame.ExportImage]()
        for tile in capturedFrame.tiles {
            guard let exportedFrame = tile.image.asExportedImage(format: format, rect: tile.rect) else {
                return nil
            }
            exportedFrames.append(exportedFrame)
        }
        guard !exportedFrames.isEmpty else { return nil }

        return ExportFrame(images: exportedFrames,
                           originalSize: capturedFrame.originalSize,
                           scale: capturedFrame.scale,
                           format: format,
                           timestamp: capturedFrame.timestamp,
                           orientation: capturedFrame.orientation,
                           isKeyframe: capturedFrame.isKeyframe,
                           imageSignature: capturedFrame.imageSignature)
    }
}
