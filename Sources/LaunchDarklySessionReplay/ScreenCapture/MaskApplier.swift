import Foundation
import UIKit

final class MaskApplier {
    private static let standardMaskColor = UIColor(white: 0.5, alpha: 1)
    private static let duplicateMaskColor = UIColor(white: 0.52, alpha: 1)
    
    init() {}
    
    func applyViewMasks(context: CGContext, operations: [MaskOperation]) {
        for operation in operations {
            switch operation.mask {
            case .affine(let rect, let transform):
                switch operation.kind {
                case .fill:
                    context.saveGState()
                    context.concatenate(transform)
                    let path = UIBezierPath(roundedRect: rect, cornerRadius: 2)
                    Self.standardMaskColor.setFill()
                    path.fill()
                    
                    context.restoreGState()
                case .fillDuplicate:
                    context.saveGState()
                    context.concatenate(transform)
                    let path = UIBezierPath(roundedRect: rect, cornerRadius: 2)
                    Self.duplicateMaskColor.setFill()
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
