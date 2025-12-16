import Foundation
import UIKit

struct ExportImage: Equatable {
    let data: Data
    let dataHashValue: Int
    let originalWidth: Int
    let originalHeight: Int
    let scale: CGFloat
    let format: ExportFormat
    let timestamp: TimeInterval
    let orientation: Int

    init(data: Data, originalWidth: Int, originalHeight: Int, scale: CGFloat, format: ExportFormat, timestamp: TimeInterval, orientation: Int) {
        self.data = data
        self.dataHashValue = data.hashValue
        self.originalWidth = originalWidth
        self.originalHeight = originalHeight
        self.scale = scale
        self.format = format
        self.timestamp = timestamp
        self.orientation = orientation
    }
    
    func eventNode(id: Int, use_rr_dataURL: Bool = true) -> EventNode {
        EventNode(
            id: id,
            type: .Element,
            tagName: "canvas",
            attributes: [
                "rr_dataURL": asBase64PNGDataURL(),
                "width": "\(originalWidth)",
                "height": "\(originalHeight)"]
        )
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
        lhs.dataHashValue == rhs.dataHashValue && lhs.data.elementsEqual(rhs.data)
    }
}

extension UIImage {
    func exportImage(format: ExportFormat, originalSize: CGSize, scale: CGFloat, timestamp: TimeInterval, orientation: Int) -> ExportImage? {
        guard let data = asData(format: format) else { return nil }
        return ExportImage(data: data,
                           originalWidth: Int(originalSize.width),
                           originalHeight: Int(originalSize.height),
                           scale: scale,
                           format: format,
                           timestamp: timestamp,
                           orientation: orientation)
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
