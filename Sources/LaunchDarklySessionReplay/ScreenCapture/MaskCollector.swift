import Foundation
import UIKit
import SwiftUI
#if LD_COCOAPODS
import LaunchDarklyObservability
#else
import Common
#endif

typealias PrivacySettings = SessionReplayOptions.PrivacyOptions

public struct OffsettedArea {
    public var rect: CGRect
    public var offset: CGPoint

    public init(rect: CGRect, offset: CGPoint) {
        self.rect = rect
        self.offset = offset
    }
}

/// Top-level orchestrator: walks every CALayer under a window and
/// produces a list of `MaskOperation`s that will be drawn over the
/// captured frame.
///
/// The heavy lifting is delegated to focused collaborators:
///   - `MaskingPolicy` — per-view/per-layer rule decisions.
///   - `MarkerScanner` — SwiftUI `.ldMask()` / `.ldUnmask()` /
///     `.ldIgnore()` marker discovery and projection.
///   - `MaskGeometry` — pure CGRect/CALayer math.
///
/// `MaskCollector` itself only owns the visit loop and the
/// transparency heuristic that lets opaque ancestors absorb their
/// children's masks.
final class MaskCollector {
    let policy: MaskingPolicy
    private let markerScanner = MarkerScanner()

    public init(privacySettings: PrivacySettings) {
        self.policy = MaskingPolicy(privacySettings: privacySettings)
    }

    func collectViewMasks(in rootView: UIView, window: UIWindow, scale: CGFloat) -> (maskOperations: [MaskOperation], offsetRects: [OffsettedArea]) {
        var operations = [MaskOperation]()
        var offsetRects = [OffsettedArea]()

        let root = rootView.layer
        let rPresentation = root.presentation() ?? root

        // Pre-pass: find every SwiftUI marker view in the subtree and
        // record its frame in root coordinates plus its explicit state.
        // SwiftUI's `.overlay(...)` sizes the marker to exactly the
        // bounding box of the modified content, so this rectangle is the
        // area the developer's modifier governs — independent of how the
        // surrounding UIKit hierarchy is shaped (siblings, deeply nested
        // wrappers, or layer-only content on iOS 26).
        //
        // We also collect the UIViews that form the marker's overlay
        // branch (the single-child wrapper chain leading from each
        // `MaskView` up to its first multi-child ancestor). Those views
        // sit at the exact same position as the marker's area; without
        // explicit suppression the geometric pass would emit duplicate
        // masks for each of them.
        //
        // When the app has no live SwiftUI markers we skip the pre-pass
        // entirely — both `markerAreas` and `overlayBranchViews` are
        // empty and the visit loop avoids every per-layer marker
        // lookup.
        let markerAreas: [MarkerScanner.MarkerArea]
        let overlayBranchViews: Set<ObjectIdentifier>
        if SessionReplayViewRepresentable.MaskView.hasLiveMarkers {
            (markerAreas, overlayBranchViews) = markerScanner.scan(in: rootView, rPresentation: rPresentation)
        } else {
            markerAreas = []
            overlayBranchViews = []
        }

        // Hoist the empty-state checks out of the hot `visit` loop so
        // every per-layer iteration becomes a branch on a captured
        // `Bool` rather than a property/function call on the
        // collections.
        let hasMarkerAreas = !markerAreas.isEmpty
        let hasOverlayBranches = !overlayBranchViews.isEmpty

        // Combines the markers whose areas contain `frameInRoot` into a
        // single override. Mask precedence is preserved by `combine`.
        // Caller is responsible for the `hasMarkerAreas` short-circuit;
        // this function is only invoked when at least one area exists.
        func markerOverride(forFrameInRoot frameInRoot: CGRect) -> MarkerScanner.MarkerOverride? {
            guard frameInRoot.width > 0, frameInRoot.height > 0 else {
                return nil
            }
            var override: MarkerScanner.MarkerOverride?
            for area in markerAreas {
                if MaskGeometry.frameContains(area.frameInRoot, frameInRoot, tolerance: 1.0) {
                    if override == nil { override = MarkerScanner.MarkerOverride() }
                    override?.combine(mask: area.mask, ignore: area.ignore)
                }
            }
            return override
        }

        // Returns `true` if a mask was emitted for this view (the caller should stop recursing).
        func emitViewMask(view: UIView, layer: CALayer, viewType: AnyClass, effectiveFrame: CGRect, resolvedExplicitMask: Bool?) -> Bool {
            let shouldMask = policy.shouldMask(view, viewType: viewType, resolvedExplicitMask: resolvedExplicitMask)

            if shouldMask, let mask = MaskGeometry.createMask(rPresentation: rPresentation, layer: layer, scale: scale) {
                var operation = MaskOperation(mask: mask, kind: .fill, effectiveFrame: effectiveFrame)
#if DEBUG
                operation.accessibilityIdentifier = view.accessibilityIdentifier
#endif
                operations.append(operation)
                return true
            }

            if let scrollView = view as? UIScrollView {
                let offset = scrollView.contentOffset
                if offset.x != 0 || offset.y != 0 {
                    offsetRects.append(OffsettedArea(rect: effectiveFrame, offset: offset))
                }
            }

            // An opaque container fully covers any masks we already emitted inside it,
            // so those masks become redundant and can be dropped.
            if operations.isNotEmpty, !isTransparent(view: view, pLayer: layer) {
                operations.removeAll { effectiveFrame.contains($0.effectiveFrame) }
            }

            return false
        }

        // iOS 26+ SwiftUI renders `Text`/`Image` directly into CALayer subclasses with no
        // backing UIView, so the UIView-based path can't see them. Match by layer class name
        // while still honouring an inherited or marker-area explicit state.
        // Returns `true` if a mask was emitted (the caller should stop recursing).
        func emitLayerOnlyMask(layer: CALayer, effectiveFrame: CGRect, resolvedExplicitMask: Bool?) -> Bool {
            let shouldMask = resolvedExplicitMask ?? policy.shouldMaskLayer(layer)
            guard shouldMask, let mask = MaskGeometry.createMask(rPresentation: rPresentation, layer: layer, scale: scale) else {
                return false
            }
            operations.append(MaskOperation(mask: mask, kind: .fill, effectiveFrame: effectiveFrame))
            return true
        }

        func visit(layer: CALayer, inheritedExplicitMask: Bool?) {
            guard !layer.isHidden, layer.opacity >= policy.minimumAlpha else { return }

            // Frame in root coords is needed both for marker-area lookup
            // and for `effectiveFrame`/`MaskOperation`. Compute it once.
            let effectiveFrame = rPresentation.convert(layer.frame, from: layer.superlayer)
            let markerOverrideForLayer = hasMarkerAreas
                ? markerOverride(forFrameInRoot: effectiveFrame)
                : nil

            let childInheritedMask: Bool?
            if let view = layer.delegate as? UIView {
                guard view.window != nil, !view.isHidden else { return }

                // The marker's overlay branch (the `MaskView` itself plus
                // the single-child wrapper chain above it) is invisible
                // and exactly co-located with the marker's area. Skip it
                // entirely so the geometric containment pass doesn't
                // emit a duplicate mask op for each wrapper.
                if hasOverlayBranches, overlayBranchViews.contains(ObjectIdentifier(view)) {
                    return
                }

                let viewType: AnyClass = type(of: view)

                if policy.shouldIgnore(view, viewType: viewType) || markerOverrideForLayer?.ignore == true {
                    return
                }

                let resolvedExplicitMask = policy.resolveExplicitMaskWithMarker(
                    view: view,
                    viewType: viewType,
                    inheritedExplicitMask: inheritedExplicitMask,
                    markerMask: markerOverrideForLayer?.mask
                )
                if emitViewMask(view: view, layer: layer, viewType: viewType, effectiveFrame: effectiveFrame, resolvedExplicitMask: resolvedExplicitMask) {
                    return
                }
                childInheritedMask = resolvedExplicitMask
            } else {
                if markerOverrideForLayer?.ignore == true { return }

                let resolvedExplicitMask: Bool?
                if inheritedExplicitMask == true || markerOverrideForLayer?.mask == true {
                    resolvedExplicitMask = true
                } else {
                    resolvedExplicitMask = inheritedExplicitMask ?? markerOverrideForLayer?.mask
                }
                if emitLayerOnlyMask(layer: layer, effectiveFrame: effectiveFrame, resolvedExplicitMask: resolvedExplicitMask) {
                    return
                }
                childInheritedMask = resolvedExplicitMask
            }

            // Recurse into sublayers in z-order. Skip the `sorted()`
            // allocation for the common case of zero or one
            // sublayers (wrapper views, leaf nodes).
            guard let sublayers = layer.sublayers, !sublayers.isEmpty else { return }
            if sublayers.count == 1 {
                visit(layer: sublayers[0], inheritedExplicitMask: childInheritedMask)
            } else {
                sublayers.sorted { $0.zPosition < $1.zPosition }
                    .forEach { visit(layer: $0, inheritedExplicitMask: childInheritedMask) }
            }
        }

        if let rootSublayers = rPresentation.sublayers, !rootSublayers.isEmpty {
            if rootSublayers.count == 1 {
                visit(layer: rootSublayers[0], inheritedExplicitMask: nil)
            } else {
                rootSublayers.sorted { $0.zPosition < $1.zPosition }
                    .forEach { visit(layer: $0, inheritedExplicitMask: nil) }
            }
        }

        return (operations, offsetRects)
    }

    // this method should be biased into transparency
    private func isTransparent(view: UIView, pLayer: CALayer) -> Bool {
        pLayer.opacity < policy.maximumAlpha
        || view.backgroundColor == nil
        || (view.backgroundColor?.cgColor.alpha ?? 0) < CGFloat(policy.maximumAlpha)
    }

    func rectFromPresentation(_ rPresentation: CALayer, root: CALayer, layer: CALayer) -> CGRect {
        let lPresentation = layer.presentation() ?? layer
        let corner1 = lPresentation.convert(CGPoint(x: 0, y: 0), to: root)
        let corner2 = lPresentation.convert(CGPoint(x: lPresentation.bounds.width, y: lPresentation.bounds.height), to: root)
        return CGRect(x: min(corner1.x, corner2.x),
                      y: min(corner1.y, corner2.y),
                      width: abs(corner2.x - corner1.x),
                      height: abs(corner2.y - corner1.y))
    }
}
