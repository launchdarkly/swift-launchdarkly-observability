import Foundation
import UIKit

struct ExportFrame: Equatable {
    struct ExportImage: Equatable {
        let data: Data
        let dataHashValue: Int
        let rect: CGRect
        
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
        
        static func == (lhs: ExportImage, rhs: ExportImage) -> Bool {
            lhs.dataHashValue == rhs.dataHashValue && lhs.data.elementsEqual(rhs.data)
        }
    }
    
    let images: [ExportImage]
    let originalSize: CGSize
    let scale: CGFloat
    let format: ExportFormat
    let timestamp: TimeInterval
    let orientation: Int
    let isKeyframe: Bool
    
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
    
    var mimeType: String {
        switch format {
        case .jpeg:
            return "image/jpeg"
        case .png:
            return "image/png"
        }
    }
    
    static func == (lhs: ExportFrame, rhs: ExportFrame) -> Bool {
        lhs.images == rhs.images
    }
}

extension UIImage {
    func asExportedImage(format: ExportFormat, rect: CGRect) -> ExportFrame.ExportImage? {
        guard let data = asData(format: format) else { return nil }
        return ExportFrame.ExportImage(data: data, dataHashValue: data.hashValue, rect: rect)
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
