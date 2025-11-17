import Foundation
import UIKit

final class MaskApplier {
    init() {}
    
    func applyViewMasks(context: CGContext, operations: [MaskOperation]) {
        for operation in operations {
            switch operation.mask {
            case .affine(let rect, let transform):
                switch operation.kind {
                case .fill:
                    context.saveGState()
                    context.concatenate(transform)
                    let path = UIBezierPath(roundedRect: rect, cornerRadius: 10)
                    UIColor.gray.setFill()
                    path.fill()
                    
                    context.restoreGState()
                case .fillDuplicate:
                    context.saveGState()
                    context.concatenate(transform)
                    let path = UIBezierPath(roundedRect: rect, cornerRadius: 2)
                    UIColor.red.setFill()
                    path.fill()
                    
                    context.restoreGState()
                case .cut:
                    continue
                }
      
            case .quad:
                () //TODO:
            }
        }
    }
}
