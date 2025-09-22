//
//  Image+Node.swift
//  ObservabilityiOSTestApp
//
//  Created by Andrey Belonogov on 9/9/25.
//

import UIKit
import LaunchDarklyObservability
import SessionReplay

//extension UIImage {
//    func asNode(id: Int? = nil, type: NodeType, data: Data) -> EventNode {
//        let imgSize = self.size
//        let base64String = data.asBase64PNGDataURL() ?? ""
//        return EventNode(
//            id: id,
//            type: type,
//            tagName: "img",
//            attributes: [
//                         "rr_dataURL": base64String,
//                         "width": "\(Int(imgSize.width * 3))",
//                         "height": "\(Int(imgSize.height * 3))"]
//        )
//    }
//}
//
//public extension UIImage {
//    enum UIImageExportFormat {
//        case png
//        case jpeg(quality: CGFloat) // 0...1
//    }
//
//    /// Export as PNG Data
//    func asPNGData() -> Data? {
//        return self.pngData()
//    }
//
//    /// Export as Data in requested format (PNG or JPEG)
//    func asData(format: UIImageExportFormat = .png) -> Data? {
//        switch format {
//        case .png:
//            return self.pngData()
//        case .jpeg(let q):
//            return self.jpegData(compressionQuality: max(0, min(1, q)))
//        }
//    }
//}
//
//public extension Data {
//    func asBase64PNGDataURL() -> String? {
//        return "data:image/png;base64,\(self.base64EncodedString())"
//    }
//}
