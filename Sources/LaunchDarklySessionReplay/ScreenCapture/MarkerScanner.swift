import Foundation
import UIKit
import SwiftUI

/// Scans a UIView hierarchy for SwiftUI marker views inserted by
/// `.ldMask()` / `.ldUnmask()` / `.ldIgnore()` and projects their
/// frames into the root layer's coordinate space.
///
/// Because `SessionReplayModifier` attaches its marker view via
/// `.overlay(...)`, the marker ends up as a *sibling* (or completely
/// disjoint, on iOS 26 Liquid Glass) of the modified content in the
/// UIKit hierarchy. Direct ancestor propagation therefore can't reach
/// the content. Instead, `MaskCollector` uses the rectangles returned
/// here as governing areas: any layer/view whose frame is contained in
/// one of these areas inherits the marker's explicit state.
final class MarkerScanner {
    /// Aggregated explicit state combined from any number of SwiftUI
    /// marker views whose areas contain the layer being evaluated.
    struct MarkerOverride {
        var mask: Bool?
        var ignore: Bool?

        /// Mask precedence: any `mask=true` wins; otherwise any `mask=false` wins.
        /// Ignore is OR-combined.
        mutating func combine(mask newMask: Bool?, ignore newIgnore: Bool?) {
            if newMask == true {
                mask = true
            } else if newMask == false, mask != true {
                mask = false
            }
            if newIgnore == true {
                ignore = true
            }
        }
    }

    /// A SwiftUI marker view's projected frame in the root layer's
    /// coordinate space, plus the explicit state the developer attached
    /// to it via `.ldMask()` / `.ldUnmask()` / `.ldIgnore()`.
    ///
    /// `.overlay()` always sizes the marker to the modified content's
    /// rendered bounds, so this rectangle *is* the area the modifier is
    /// supposed to govern — regardless of how SwiftUI flattens the
    /// surrounding UIKit/CALayer hierarchy. During collection we apply
    /// the marker's state to any layer whose own frame is contained
    /// inside this rectangle.
    struct MarkerArea {
        var frameInRoot: CGRect
        var mask: Bool?
        var ignore: Bool?
    }

    /// Walks the UIView hierarchy under `rootView` and records:
    /// 1. A `MarkerArea` for every `SessionReplayViewRepresentable.MaskView`,
    ///    whose rectangle is the marker's bounds projected into
    ///    `rPresentation`'s coordinate space.
    /// 2. The set of UIViews that form the *overlay branch wrapper
    ///    chain* — the marker view itself plus every ancestor with
    ///    exactly one subview, walking up until we hit a multi-child
    ///    ancestor. These wrappers are co-located with the marker area
    ///    but contain no visible content of their own; the visit pass
    ///    must skip them or every wrapper would receive a duplicate
    ///    mask operation.
    ///
    /// Because SwiftUI's `.overlay(...)` always sizes the marker to the
    /// modified content's bounding box, this rectangle is exactly the
    /// area the developer's `.ldMask()` / `.ldUnmask()` / `.ldIgnore()`
    /// modifier governs — regardless of whether SwiftUI flattens that
    /// content into a UIView sibling, a deeply nested UIView, or a pure
    /// CALayer (iOS 26 Liquid Glass).
    func scan(
        in rootView: UIView,
        rPresentation: CALayer
    ) -> (areas: [MarkerArea], overlayBranchViews: Set<ObjectIdentifier>) {
        var areas: [MarkerArea] = []
        var overlayBranchViews: Set<ObjectIdentifier> = []

        // Iterative DFS using a reusable stack avoids the per-call
        // closure/frame allocation of recursion on busy screens. A
        // typical screen has 100-500 UIViews and this runs once per
        // capture frame.
        var stack: [UIView] = [rootView]
        stack.reserveCapacity(64)
        while let view = stack.popLast() {
            if let marker = view as? SessionReplayViewRepresentable.MaskView,
               marker.window != nil {
                Self.recordOverlayBranch(of: marker, into: &overlayBranchViews)

                let mask = SessionReplayAssociatedObjects.shouldMaskUIView(marker)
                let ignore = SessionReplayAssociatedObjects.shouldIgnoreUIView(marker)
                if mask != nil || ignore != nil {
                    // `MaskCollector.collectViewMasks` recurses through
                    // `rPresentation.sublayers`, so every `effectiveFrame`
                    // it later compares against is computed in pure
                    // presentation coordinates. We must project the
                    // marker through its own presentation layer too —
                    // otherwise during an active animation (e.g. a
                    // horizontal navigation push/pop) the `from:` chain
                    // reads model `transform`/`position` while the
                    // receiver `rPresentation` is mid-animation, the
                    // resulting `frameInRoot` lands in the wrong
                    // coordinate system, and `frameContains` checks fail
                    // for every visited layer until the animation
                    // finishes. `presentation()` returns nil when the
                    // layer isn't animating, in which case model and
                    // presentation are identical and the fallback is
                    // exact.
                    let markerLayer = marker.layer.presentation() ?? marker.layer
                    let frameInRoot = rPresentation.convert(markerLayer.bounds, from: markerLayer)
                    if frameInRoot.width > 0, frameInRoot.height > 0 {
                        areas.append(MarkerArea(frameInRoot: frameInRoot, mask: mask, ignore: ignore))
                    }
                }
                // `MaskView` is a leaf in our hierarchy — we never add
                // subviews to it. UIKit also won't add any. Skip
                // descending.
                continue
            }
            stack.append(contentsOf: view.subviews)
        }

        return (areas, overlayBranchViews)
    }

    /// Adds the `MaskView` and the wrapper chain immediately above it
    /// to `set`. The wrappers we want to skip are bridging views whose
    /// only purpose is to host the marker itself; they are
    /// distinguishable by two simultaneous properties:
    ///
    ///   1. The parent has exactly one subview (the chain wrapper).
    ///   2. The parent's bounds are the same size as the marker.
    ///
    /// Property 1 alone is *not* enough: a real content host such as
    /// SwiftUI's `CellHostingView` can also have a single subview (the
    /// marker's wrapper) while still owning the actual rendered content
    /// as sublayers — and its bounds are much larger than the marker.
    /// Walking past that host would cause `visit` to skip the entire
    /// content subtree, eliminating every mask op.
    private static func recordOverlayBranch(
        of marker: SessionReplayViewRepresentable.MaskView,
        into set: inout Set<ObjectIdentifier>
    ) {
        let markerSize = marker.bounds.size
        let tolerance: CGFloat = 1.0

        var current: UIView = marker
        while true {
            set.insert(ObjectIdentifier(current))
            guard let parent = current.superview,
                  parent.subviews.count == 1,
                  abs(parent.bounds.width - markerSize.width) <= tolerance,
                  abs(parent.bounds.height - markerSize.height) <= tolerance else {
                break
            }
            current = parent
        }
    }
}
