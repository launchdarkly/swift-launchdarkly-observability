import Foundation
import UIKit

final class MaskApplier {
    private static let standardMaskColor = UIColor(white: 0.5, alpha: 1)
    private static let duplicateMaskColor = UIColor(white: 0.52, alpha: 1)
    
    init() {}
    
    func applyViewMasks(context: CGContext, operations: [(MaskOperation, MaskOperation?)]) {
        for (before, after) in operations {
            // Cover the transition area between the two passes via a
            // convex hull. Both mask cases reduce to a quad, so the hull
            // is built even when `before` and `after` use different
            // cases (e.g. affine before and quad after when a layer
            // crosses a 3D transform between passes).
            if let after {
                context.saveGState()
                drawHull(context,
                         quad1: quad(from: before.mask),
                         quad2: quad(from: after.mask),
                         fillColor: Self.standardMaskColor)
                context.restoreGState()
            }

            context.saveGState()
            switch before.mask {
            case .affine(let rect, let transform):
                drawRect(context, transform, rect, fillColor: Self.duplicateMaskColor)
            case .quad(let beforeQuad):
                drawQuad(context, quad: beforeQuad, fillColor: Self.duplicateMaskColor)
            }
            context.restoreGState()
        }
    }

    private func quad(from mask: Mask) -> Quad {
        switch mask {
        case .affine(let rect, let transform):
            return quadFrom(rect: rect, transform: transform)
        case .quad(let quad):
            return quad
        }
    }
    
    private func drawRect(_ context: CGContext, _ transform: CGAffineTransform, _ rect: CGRect, fillColor: UIColor) {
        context.concatenate(transform)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 2)
        fillColor.setFill()
        path.fill()
    }
    
    private func quadFrom(rect: CGRect, transform: CGAffineTransform) -> Quad {
        let p0 = CGPoint(x: rect.minX, y: rect.minY).applying(transform)
        let p1 = CGPoint(x: rect.maxX, y: rect.minY).applying(transform)
        let p2 = CGPoint(x: rect.maxX, y: rect.maxY).applying(transform)
        let p3 = CGPoint(x: rect.minX, y: rect.maxY).applying(transform)
        return Quad(p0: p0, p1: p1, p2: p2, p3: p3)
    }
    
    private func drawQuad(_ context: CGContext, quad: Quad, fillColor: UIColor) {
        context.beginPath()
        context.move(to: quad.p0)
        context.addLine(to: quad.p1)
        context.addLine(to: quad.p2)
        context.addLine(to: quad.p3)
        context.addLine(to: quad.p0)
        fillColor.setFill()
        context.fillPath()
    }
    
    private func drawHull(_ context: CGContext, quad1: Quad, quad2: Quad, fillColor: UIColor) {
        let hull = convexHull8([quad1.p0,
                                quad1.p1,
                                quad1.p2,
                                quad1.p3,
                                quad2.p0,
                                quad2.p1,
                                quad2.p2,
                                quad2.p3])
        guard hull.count >= 3 else { return }
        
        let path = CGMutablePath()
        path.move(to: hull[0])
        for i in 1..<hull.count {
            path.addLine(to: hull[i])
        }
        path.closeSubpath()
        
        context.addPath(path)
        context.setFillColor(fillColor.cgColor)
        context.fillPath(using: .winding)
    }
}

@inline(__always)
func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
    (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
}

// Optimized for a small number of points (~8): uses a gift-wrapping
// search instead of a sort-based hull.
func convexHull8(_ points: [CGPoint]) -> [CGPoint] {
    guard points.count >= 4 else { return points }
    
    var hull: [CGPoint] = []
    hull.reserveCapacity(points.count)
    
    guard let startPoint = points.min(by: { $0.x < $1.x }) else { return points }
    var currentPoint: CGPoint = startPoint
    
    repeat {
        hull.append(currentPoint)
        var nextPoint = points[0]
        
        for i in 0..<points.count {
            if nextPoint == currentPoint {
                nextPoint = points[i]
                continue
            }
            
            let turn = cross(currentPoint, points[i], nextPoint)
            if turn < 0 {
                nextPoint = points[i]
            }
        }
        currentPoint = nextPoint
    } while currentPoint != startPoint
    
    return hull
}
