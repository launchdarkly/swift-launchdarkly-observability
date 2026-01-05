import Foundation
import UIKit

final class MaskApplier {
    private static let standardMaskColor = UIColor(white: 0.5, alpha: 1)
    private static let duplicateMaskColor = UIColor(white: 0.52, alpha: 1)
    
    init() {}
    
    func applyViewMasks(context: CGContext, operations: [(MaskOperation, MaskOperation?)]) {
        for (before, after) in operations {
            switch before.mask {
            case .affine(let rect, let transform):
                if let after {
                    
                }
                
                context.saveGState()
                drawRect(context, transform, rect, fillColor: Self.standardMaskColor)
                context.restoreGState()
                
            case .quad(let beforeQuad):
                if let after, case .quad(let afterQuad) = after.mask {
                    // merging 2 rectangles
                    context.saveGState()
                    drawHull(context, quad1: beforeQuad, quad2: afterQuad, fillColor: Self.standardMaskColor)
                    context.restoreGState()
                } //else {
                // one rectangle case
                context.saveGState()
                drawQuad(context, quad: beforeQuad, fillColor: Self.duplicateMaskColor)
                
                context.restoreGState()
                //}
            }
        }
    }
    
    private func drawRect(_ context: CGContext, _ transform: CGAffineTransform, _ rect: CGRect, fillColor: UIColor) {
        context.concatenate(transform)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 2)
        fillColor.setFill()
        path.fill()
    }
    
    private func drawQuad(_ context: CGContext, /*_ transform: CGAffineTransform,*/ quad: Quad, fillColor: UIColor) {
        //context.concatenate(transform)
        context.beginPath()
        context.move(to: quad.p0)
        context.addLine(to: quad.p1)
        context.addLine(to: quad.p2)
        context.addLine(to: quad.p3)
        context.addLine(to: quad.p0)
        //let path = UIBezierPath(cornerRadius: 2)
        fillColor.setFill()
        context.fillPath()
    }
    
    private func drawQuads(_ context: CGContext, quad1: Quad, quad2: Quad, fillColor: UIColor) {
        let path = CGMutablePath()
        
        path.move(to: quad1.p0)
        path.addLine(to: quad1.p1)
        path.addLine(to: quad1.p2)
        path.addLine(to: quad1.p3)
        path.closeSubpath()
        
        path.move(to: quad2.p0)
        path.addLine(to: quad2.p1)
        path.addLine(to: quad2.p2)
        path.addLine(to: quad2.p3)
        path.closeSubpath()
        
        context.addPath(path)
        context.setFillColor(fillColor.cgColor)
        context.fillPath(using: .winding)
    }
    
    private func drawHull(_ context: CGContext, quad1: Quad, quad2: Quad, fillColor: UIColor) {
        let hull = convexHull([quad1.p0,
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
        
        context.addPath(path)
        context.setFillColor(fillColor.cgColor)
        context.fillPath(using: .winding)
    }
}

@inline (__always)
func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
    (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
}

// Optimized for small number of points ~8 (no need to use sort and use search instead)
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

// General for a lot of points
func convexHull(_ points: [CGPoint]) -> [CGPoint] {
    guard points.count >= 4 else { return points }
    
    let sortedPoints = points.sorted {
        if $0.x != $1.x { return $0.x < $1.x }
        return $0.y < $1.y
    }
    
    var lower: [CGPoint] = []
    lower.reserveCapacity(points.count)
    
    for p in sortedPoints {
        while lower.count >= 2 {
            let a = lower[lower.count - 2]
            let b = lower[lower.count - 1]
            
            guard cross(a, b, p) <= 0 else { break }
            lower.removeLast()
        }
        lower.append(p)
    }
    
    var upper: [CGPoint] = []
    upper.reserveCapacity(points.count)
    
    for p in sortedPoints.reversed() {
        while upper.count >= 2 {
            let a = upper[upper.count - 2]
            let b = upper[upper.count - 1]
            
            guard cross(a, b, p) <= 0 else { break }
            upper.removeLast()
        }
        upper.append(p)
    }
    
    lower.removeLast()
    upper.removeLast()
    
    return lower + upper
}
