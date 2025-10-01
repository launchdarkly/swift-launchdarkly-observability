import Foundation
import UIKit

final class MaskService {
    public init() {
    }
    
    func applyViewMasks(viewMasks: [ViewMask]) {
        for viewMask in viewMasks {
            let path = UIBezierPath(roundedRect: viewMask.rect, cornerRadius: 4)
            UIColor.gray.setFill()
            path.fill()
        }
    }
}

func applyBlurInPlace(bytes: UnsafeMutableRawPointer, width: Int, height: Int) {
    
}
