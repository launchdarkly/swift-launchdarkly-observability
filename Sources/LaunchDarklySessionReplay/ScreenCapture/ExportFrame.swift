import Foundation
import UIKit

struct ExportFrame {
    struct RemoveImage {
        let keyFrameId: Int
        let imageSignature: ImageSignature
    }
    
    struct AddImage {
        let data: Data
        let rect: CGRect
        let imageSignature: ImageSignature?
        
        /// Creates an EventNode for a tile image (positioned absolutely on top of main canvas)
        func tileEventNode(id: Int, rr_dataURL: String) -> EventNode {
            let style = "position:absolute;left:\(Int(rect.minX))px;top:\(Int(rect.minY))px;pointer-events:none;"
            return EventNode(
                id: id,
                type: .Element,
                tagName: "img",
                attributes: [
                    "src": rr_dataURL,
                    "width": "\(Int(rect.width))",
                    "height": "\(Int(rect.height))",
                    "style": style]
            )
        }
        
        func base64DataURL(mimeType: String) -> String {
            "data:\(mimeType);base64,\(data.base64EncodedString())"
        }
    }
    
    let keyFrameId: Int
    let addImages: [AddImage]
    let removeImages: [RemoveImage]?
    let originalSize: CGSize
    let scale: CGFloat
    let format: ExportFormat
    let timestamp: TimeInterval
    let orientation: Int
    let isKeyframe: Bool
    let imageSignature: ImageSignature?
    
    var mimeType: String {
        switch format {
        case .jpeg:
            return "image/jpeg"
        case .png:
            return "image/png"
        }
    }
}

extension UIImage {
    func asExportedImage(format: ExportFormat, rect: CGRect, imageSignature: ImageSignature?) -> ExportFrame.AddImage? {
        guard let data = asData(format: format) else { return nil }
        return ExportFrame.AddImage(data: data, rect: rect, imageSignature: imageSignature)
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
