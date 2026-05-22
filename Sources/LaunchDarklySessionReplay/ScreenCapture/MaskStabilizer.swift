import Foundation
import UIKit

/// Reconciles two mask collections captured for the same set of windows
/// across two consecutive runloop ticks (the "before" and "after"
/// passes around `ImageCaptureService.captureRawFrame`). When views
/// shift slightly between the two passes — typical during scrolling or
/// keyboard animations — the same logical mask occupies two nearby
/// frames; we keep both and tag the second one as
/// ``MaskOperation/Kind/fillDuplicate`` so the renderer covers the
/// transition area instead of leaving a sliver of unmasked content.
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

    /// Returns a merged operation list that includes every operation
    /// from `operationsBefore` plus a `fillDuplicate` copy of any
    /// `operationsAfter` element that shifted enough to expose
    /// previously-masked content. Returns `nil` (the caller should
    /// drop the frame) when an op moved further than its own size,
    /// because we can't guarantee coverage of the in-between area.
    func duplicateUnsimilar(before operationsBefore: [MaskOperation], after operationsAfter: [MaskOperation]) -> [MaskOperation]? {
        guard operationsBefore.count == operationsAfter.count else {
            return nil
        }

        var result = operationsBefore
        for (before, after) in zip(operationsBefore, operationsAfter) {
            let diffX = abs(before.effectiveFrame.minX - after.effectiveFrame.minX)
            let diffY = abs(before.effectiveFrame.minY - after.effectiveFrame.minY)

            guard max(diffX, diffY) > moveTolerance else {
                // Movement is within tolerance; the "before" mask
                // already covers the same area.
                continue
            }

            guard diffX * overlapTolerance < before.effectiveFrame.width - moveTolerance,
                  diffY * overlapTolerance < before.effectiveFrame.height - moveTolerance else {
                // Moved further than its own size; the gap between
                // before and after can't be safely covered.
                return nil
            }

            var after = after
            after.kind = .fillDuplicate
            result.append(after)
        }

        return result
    }
}
