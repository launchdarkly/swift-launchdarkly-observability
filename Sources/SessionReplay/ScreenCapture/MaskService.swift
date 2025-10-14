import Foundation
import UIKit

final class MaskService {
    public init() {
    }
    
    func applyViewMasks(context: CGContext, operations: [MaskOperation]) {
        for operation in operations {
            switch operation.mask {
            case .affine(let rect, let transform):
                context.saveGState()
                context.concatenate(transform)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 2)
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
