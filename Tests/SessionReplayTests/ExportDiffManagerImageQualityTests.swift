import Testing
@testable import LaunchDarklySessionReplay
import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit

struct ExportDiffManagerImageQualityTests {
    private let screenSize = CGSize(width: 120, height: 88)

    @Test("frames are exported as JPEG")
    func framesAreExportedAsJpeg() throws {
        let manager = ExportDiffManager(compression: .screenImage, scale: 1.0, imageQuality: 0.3)
        let exportFrame = try #require(manager.exportFrame(from: makeGradientFrame(timestamp: 1.0)))

        #expect(exportFrame.mimeType == "image/jpeg")
        let data = try #require(exportFrame.addImages.first?.data)
        // JPEG start-of-image marker.
        #expect(data.prefix(2) == Data([0xFF, 0xD8]))
    }

    @Test("the configured image quality drives JPEG encoding")
    func configuredImageQualityIsUsedForJpegEncoding() throws {
        let lowQualitySize = try encodedSize(imageQuality: 0.1)
        let highQualitySize = try encodedSize(imageQuality: 0.9)

        #expect(lowQualitySize < highQualitySize)
    }

    private func encodedSize(imageQuality: CGFloat) throws -> Int {
        let manager = ExportDiffManager(compression: .screenImage, scale: 1.0, imageQuality: imageQuality)
        let exportFrame = try #require(manager.exportFrame(from: makeGradientFrame(timestamp: 1.0)))
        return try #require(exportFrame.addImages.first?.data.count)
    }

    /// A frame with enough high-frequency detail that the JPEG quality factor
    /// makes a measurable difference in the encoded size.
    private func makeGradientFrame(timestamp: TimeInterval) -> RawFrame {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: screenSize, format: format)
        let image = renderer.image { context in
            for x in stride(from: 0, to: screenSize.width, by: 2) {
                for y in stride(from: 0, to: screenSize.height, by: 2) {
                    UIColor(hue: (x + y) / (screenSize.width + screenSize.height),
                            saturation: 1,
                            brightness: y / screenSize.height,
                            alpha: 1).setFill()
                    context.fill(CGRect(x: x, y: y, width: 2, height: 2))
                }
            }
        }
        return RawFrame(image: image, timestamp: timestamp, orientation: 0, areas: [])
    }
}

#endif
