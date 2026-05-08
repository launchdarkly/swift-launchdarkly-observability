import Foundation
import UIKit

/// Stateless geometry helpers used by the mask-collection pipeline.
///
/// These functions don't depend on any privacy configuration or
/// hierarchy state — they're pure CGRect/CALayer math kept separate
/// from `MaskCollector` so the orchestrator can stay focused on the
/// visit loop.
enum MaskGeometry {
    /// Builds a `Mask` describing where `layer` lands inside
    /// `rPresentation` when drawn at the given `scale`. Returns `nil`
    /// when the layer has zero area or uses a non-affine transform we
    /// don't yet handle.
    static func createMask(rPresentation: CALayer, layer: CALayer, scale: CGFloat) -> Mask? {
        let lBounds = layer.bounds
        guard lBounds.width > 0, lBounds.height > 0 else { return nil }

        if CATransform3DIsAffine(layer.transform) {
            let corner0 = layer.convert(CGPoint.zero, to: rPresentation)
            let corner1 = layer.convert(CGPoint(x: lBounds.width, y: 0), to: rPresentation)
            let corner3 = layer.convert(CGPoint(x: 0, y: lBounds.height), to: rPresentation)

            let tx = corner0.x, ty = corner0.y
            let affineTransform = CGAffineTransform(a: (corner1.x - tx) / max(lBounds.width, 0.0001),
                                                    b: (corner1.y - ty) / max(lBounds.width, 0.0001),
                                                    c: (corner3.x - tx) / max(lBounds.height, 0.0001),
                                                    d: (corner3.y - ty) / max(lBounds.height, 0.0001),
                                                    tx: tx,
                                                    ty: ty).scaledBy(x: scale, y: scale)
            return Mask.affine(rect: lBounds, transform: affineTransform)
        } else {
            // TODO: finish 3D animations
        }

        return nil
    }

    /// `true` if `inner` is fully inside `container` (within `tolerance`
    /// in every direction). Used both as the geometry check that decides
    /// which layers a marker area governs and as a building block for
    /// `MarkerArea` lookups during the visit pass.
    static func frameContains(_ container: CGRect, _ inner: CGRect, tolerance: CGFloat) -> Bool {
        inner.minX >= container.minX - tolerance &&
        inner.minY >= container.minY - tolerance &&
        inner.maxX <= container.maxX + tolerance &&
        inner.maxY <= container.maxY + tolerance
    }
}
