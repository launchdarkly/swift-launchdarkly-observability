import Foundation
import UIKit

struct ExportImage: Equatable {
    let data: Data
    let dataHashValue: Int
    let rect: CGRect
    let originalSize: CGSize
    let scale: CGFloat
    let format: ExportFormat
    let timestamp: TimeInterval
    let orientation: Int
    let isKeyframe: Bool

    init(data: Data, dataHashValue: Int,
         rect: CGRect,
         originalSize: CGSize,
         scale: CGFloat,
         format: ExportFormat,
         timestamp: TimeInterval,
         orientation: Int,
         isKeyframe: Bool) {
        self.data = data
        self.dataHashValue = dataHashValue
        self.rect = rect
        self.originalSize = originalSize
        self.scale = scale
        self.format = format
        self.timestamp = timestamp
        self.orientation = orientation
        self.isKeyframe = isKeyframe
    }
    
    /// Creates an EventNode for the main canvas (full snapshot)
    func eventNode(id: Int, rr_dataURL: String) -> EventNode {
        EventNode(
            id: id,
            type: .Element,
            tagName: "canvas",
            attributes: [
                "rr_dataURL": rr_dataURL,
                "width": "\(Int(originalSize.width))",
                "height": "\(Int(originalSize.height))"]
        )
    }
    
    /// Creates an EventNode for a tile canvas (positioned absolutely on top of main canvas)
    func tileEventNode(id: Int, rr_dataURL: String) -> EventNode {
        let style = "position:absolute;left:\(Int(rect.minX))px;top:\(Int(rect.minY))px;pointer-events:none;"
        return EventNode(
            id: id,
            type: .Element,
            tagName: "canvas",
            attributes: [
                "rr_dataURL": rr_dataURL,
                "width": "\(Int(rect.width))",
                "height": "\(Int(rect.height))",
                "style": style]
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
    
    func base64DataURL() -> String {
        "data:\(mimeType);base64,\(data.base64EncodedString())"
    }
    
    static func == (lhs: ExportImage, rhs: ExportImage) -> Bool {
        lhs.dataHashValue == rhs.dataHashValue && lhs.data.elementsEqual(rhs.data)
    }
}

extension UIImage {
    func exportImage(format: ExportFormat,
                     rect: CGRect,
                     originalSize: CGSize,
                     scale: CGFloat,
                     timestamp: TimeInterval,
                     orientation: Int,
                     isKeyframe: Bool) -> ExportImage? {
        guard let data = asData(format: format) else { return nil }
        return ExportImage(data: data,
                           dataHashValue: data.hashValue,
                           rect: rect,
                           originalSize: originalSize,
                           scale: scale,
                           format: format,
                           timestamp: timestamp,
                           orientation: orientation,
                           isKeyframe: isKeyframe)
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
