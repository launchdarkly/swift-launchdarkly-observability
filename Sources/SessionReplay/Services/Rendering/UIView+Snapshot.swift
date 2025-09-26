#if canImport(UIKit)

import UIKit

extension UIView {
    
    // keeps blue/transparency effects
    func accurateSnapshot(afterScreenUpdates: Bool = false,
                          opaque: Bool = false,
                          scale: CGFloat = 0) -> UIImage? {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = opaque
        format.scale = scale == 0 ? layer.contentsScale : scale
        
        return UIGraphicsImageRenderer(bounds: bounds, format: format).image { context in
            drawHierarchy(in: bounds, afterScreenUpdates: afterScreenUpdates)
        }
    }
}

#endif
