import Foundation

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

