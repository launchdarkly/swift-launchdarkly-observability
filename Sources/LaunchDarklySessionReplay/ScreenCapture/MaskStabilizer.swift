import Foundation
import UIKit

/// Reconciles two mask collections captured for the same set of windows
/// across two consecutive runloop ticks (the "before" and "after"
/// passes around `ImageCaptureService.captureRawFrame`). When views
/// shift slightly between the two passes — typical during scrolling or
/// keyboard animations — the same logical mask occupies two nearby
/// frames; we pair the "before" op with its shifted "after" counterpart
/// so the renderer can cover the transition area (via a convex hull of
/// both positions) instead of leaving a sliver of unmasked content.
///
/// The reconciliation is purely functional: it doesn't read any
/// privacy settings or hierarchy state, only the geometry of the two
/// `MaskOperation` lists.
final class MaskStabilizer {
    /// Movement under this many points (in any axis) is treated as the
    /// same position; the corresponding "after" op is discarded as a
    /// duplicate of "before".
    private let moveTolerance: CGFloat = 1.0

    /// Required slack between the observed delta and the mask's own
    /// width/height: if a mask drifted further than itself between the
    /// two passes the gap can't be safely covered, so the whole frame
    /// is dropped.
    private let overlapTolerance: CGFloat = 1.1

    /// Returns one entry per "before" operation, paired with its shifted
    /// "after" counterpart when the mask moved enough to expose
    /// previously-masked content (the renderer spans the gap by drawing
    /// the convex hull of both positions). The "after" element is `nil`
    /// when movement is within tolerance and the "before" mask already
    /// covers the area. Returns `nil` (the caller should drop the frame)
    /// when an op moved further than its own size, because we can't
    /// guarantee coverage of the in-between area.
    func duplicateUnsimilar(before operationsBefore: [MaskOperation], after operationsAfter: [MaskOperation]) -> [(MaskOperation, MaskOperation?)]? {
        guard operationsBefore.count == operationsAfter.count else {
            return nil
        }

        var result = [(MaskOperation, MaskOperation?)]()
        result.reserveCapacity(operationsBefore.count)
        for (before, after) in zip(operationsBefore, operationsAfter) {
            let diffX = abs(before.effectiveFrame.minX - after.effectiveFrame.minX)
            let diffY = abs(before.effectiveFrame.minY - after.effectiveFrame.minY)

            guard max(diffX, diffY) > moveTolerance else {
                // Movement is within tolerance; the "before" mask
                // already covers the same area.
                result.append((before, nil))
                continue
            }

            guard diffX * overlapTolerance < before.effectiveFrame.width - moveTolerance,
                  diffY * overlapTolerance < before.effectiveFrame.height - moveTolerance else {
                // Moved further than its own size; the gap between
                // before and after can't be safely covered.
                return nil
            }

            result.append((before, after))
        }

        return result
    }
}
