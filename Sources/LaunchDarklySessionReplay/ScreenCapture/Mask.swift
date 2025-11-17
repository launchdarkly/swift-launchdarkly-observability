import Foundation
import UIKit

struct Quad {
    let p0: CGPoint
    let p1: CGPoint
    let p2: CGPoint
    let p3: CGPoint
}

enum Mask {
    case affine(rect: CGRect, transform: CGAffineTransform)
    case quad(Quad)
}

struct MaskOperation {
    enum Kind {
        case fill
        case fillDuplicate
        case cut
    }
    
    var mask: Mask
    var kind: Kind
    var view: UIView
    var effectiveFrame: CGRect
    
    #if DEBUG
    var accessibilityIdentifier: String?
    #endif
}


