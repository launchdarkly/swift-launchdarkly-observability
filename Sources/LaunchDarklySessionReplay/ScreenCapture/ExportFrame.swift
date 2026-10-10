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
        
        /// Creates an EventNode for a tile image (positioned absolutely on top of main canvas).
        ///
        /// The image goes in as bytes: it is base64-encoded straight into the payload when the node is written, so the
        /// tile is never held as a `data:` URL string as well.
        func tileEventNode(id: Int, mimeType: String) -> EventNode {
            let style = "position:absolute;left:\(Int(rect.minX))px;top:\(Int(rect.minY))px;pointer-events:none;"
            return EventNode(
                id: id,
                type: .Element,
                tagName: "img",
                attributes: [
                    "src": .imageDataURL(mimeType: mimeType, data: data),
                    "width": "\(Int(rect.width))",
                    "height": "\(Int(rect.height))",
                    "style": .text(style)]
            )
        }
        
        /// The length of this tile's `data:` URL once written, which is what the player's canvas budget counts.
        func dataURLByteCount(mimeType: String) -> Int {
            JSONWriter.base64DataURLByteCount(mimeType: mimeType, byteCount: data.count)
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
