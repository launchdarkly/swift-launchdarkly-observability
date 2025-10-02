import Foundation
import UIKit

final class MaskService {
    public init() {
    }
    
    func applyViewMasks(context: CGContext, viewMasks: [Mask]) {
        for viewMask in viewMasks {
            switch viewMask {
            case .affine(let rect, let transform):
                context.saveGState()
                context.concatenate(transform)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 4)
                UIColor.gray.setFill()
                path.fill()
                
                context.restoreGState()
                
            case .quad:
                () //TODO:
            }
        }
    }
}

func applyBlurInPlace(bytes: UnsafeMutableRawPointer, width: Int, height: Int) {
    
}
