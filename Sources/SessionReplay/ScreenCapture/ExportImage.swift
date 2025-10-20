import Foundation
import UIKit

struct ExportImage: Equatable {
    var data: Data
    var originalWidth: Int
    var originalHeight: Int
    var scale: CGFloat
    var format: ExportFormat
    var timestamp: TimeInterval
    
    func eventNode(id: Int, use_rr_dataURL: Bool = true) -> EventNode {
        if use_rr_dataURL {
            return EventNode(
                id: id,
                type: .Element,
                tagName: "canvas",
                attributes: [
                    "rr_dataURL": asBase64PNGDataURL(),
                    "width": "\(originalWidth)",
                    "height": "\(originalHeight)"]
            )
        } else {
            return EventNode(
                id: id,
                type: .Element,
                tagName: "canvas",
                attributes: [
                    "width": "\(originalWidth)",
                    "height": "\(originalHeight)"]
            )
        }
    }
    
    var mimeType: String {
        switch format {
        case .jpeg:
            return "image/jpeg"
        case .png:
            return "image/png"
        }
    }
    
    func asBase64PNGDataURL() -> String {
        "data:\(mimeType);base64,\(data.base64EncodedString())"
    }
    
    static func == (lhs: ExportImage, rhs: ExportImage) -> Bool {
        return lhs.data == rhs.data
    }
    
    var paddedWidth: Int {
        originalWidth * 105 / 100
    }
    
    var paddedHeight: Int {
        originalHeight * 105 / 100
    }
}

extension UIImage {
    func exportImage(format: ExportFormat, originalSize: CGSize, scale: CGFloat, timestamp: TimeInterval) -> ExportImage? {
        guard let data = asData(format: format) else { return nil }
        return ExportImage(data: data,
                           originalWidth: Int(originalSize.width),
                           originalHeight: Int(originalSize.height),
                           scale: scale,
                           format: format,
                           timestamp: timestamp)
    }
}

enum ExportFormat {
    case png
    case jpeg(quality: CGFloat) // 0...1
}

extension UIImage {
    /// Export as Data in requested format (PNG or JPEG)
    func asData(format: ExportFormat = .png) -> Data? {
        switch format {
        case .png:
            return self.pngData()
        case .jpeg(let q):
            return self.jpegData(compressionQuality: max(0, min(1, q)))
        }
    }
}
