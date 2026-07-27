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

        // Masks have to line up with what the render server is drawing.
        // Presentation layers carry the live value of every running
        // animation (transform, position, opacity); model layers only hold
        // the final state, and a rotation driven purely by a CAAnimation
        // never touches the model at all. Building masks from model layers
        // therefore drops the rotation entirely and leaves an axis-aligned
        // rectangle at the view's resting frame.
        //
        // The exception is a tree containing private CameraUI layers
        // (iOS 26+): they don't implement `init(layer:)` and trap as soon as
        // Core Animation builds a presentation copy anywhere in their
        // ancestry. When one is present we fall back to model geometry for
        // the whole pass — animation accuracy for camera chrome is a fair
        // trade against a fatal crash.
        let usePresentationGeometry = !containsUnsafeLayer(root)
        let rPresentation = usePresentationGeometry ? (root.presentation() ?? root) : root

        // Presentation copy of a model layer, used for all geometry reads.
        // `presentation()` returns nil when the layer isn't animating, and
        // then the model layer is exact.
        func geometryLayer(for modelLayer: CALayer) -> CALayer {
            guard usePresentationGeometry else { return modelLayer }
            return modelLayer.presentation() ?? modelLayer
        }

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
            (markerAreas, overlayBranchViews) = markerScanner.scan(
                in: rootView,
                rPresentation: rPresentation,
                usePresentationGeometry: usePresentationGeometry
            )
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
        func emitViewMask(view: UIView, layer: CALayer, viewType: AnyClass, className: String, effectiveFrame: CGRect, resolvedExplicitMask: Bool?) -> Bool {
            let shouldMask = policy.shouldMask(view, viewType: viewType, className: className, resolvedExplicitMask: resolvedExplicitMask)

            if shouldMask, let mask = MaskGeometry.createMask(rPresentation: rPresentation, layer: layer, scale: scale) {
                var operation = MaskOperation(mask: mask, effectiveFrame: effectiveFrame)
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
        func emitLayerOnlyMask(layerClassName: String, layer: CALayer, effectiveFrame: CGRect, resolvedExplicitMask: Bool?) -> Bool {
            let shouldMask = resolvedExplicitMask ?? policy.shouldMaskLayer(className: layerClassName)
            guard shouldMask, let mask = MaskGeometry.createMask(rPresentation: rPresentation, layer: layer, scale: scale) else {
                return false
            }
            operations.append(MaskOperation(mask: mask, effectiveFrame: effectiveFrame))
            return true
        }

        func visit(layer: CALayer, layerClassName: String, inheritedExplicitMask: Bool?) {
            // On iOS 26+, CameraUI private CALayer subclasses (e.g. ModeLoupeLayer) do not
            // implement init(layer:). Guard at the very top — before ANY property access —
            // because even isHidden/opacity access can trigger CA::Layer::presentation_layer()
            // on a layer that lacks the initializer. `layerClassName` is computed once by
            // the caller so we never call NSStringFromClass twice for the same layer.
            if policy.shouldSkipLayer(className: layerClassName) { return }

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
                let viewClassName = NSStringFromClass(viewType)

                if policy.shouldIgnore(view, viewType: viewType, className: viewClassName) || markerOverrideForLayer?.ignore == true {
                    return
                }

                let resolvedExplicitMask = policy.resolveExplicitMaskWithMarker(
                    view: view,
                    viewType: viewType,
                    inheritedExplicitMask: inheritedExplicitMask,
                    markerMask: markerOverrideForLayer?.mask
                )
                if emitViewMask(view: view,
                                layer: layer,
                                viewType: viewType,
                                className: viewClassName,
                                effectiveFrame: effectiveFrame,
                                resolvedExplicitMask: resolvedExplicitMask) {
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
                if emitLayerOnlyMask(layerClassName: layerClassName, layer: layer, effectiveFrame: effectiveFrame, resolvedExplicitMask: resolvedExplicitMask) {
                    return
                }
                childInheritedMask = resolvedExplicitMask
            }

            // Recurse into sublayers in z-order.
            //
            // Enumerate the *model* sublayers: reading `.sublayers` on a
            // presentation layer makes Core Animation build presentation copies
            // of every child eagerly, which crashes on iOS 26+ when a child is
            // CameraUI.ModeLoupeLayer. Each child is then mapped to its own
            // presentation copy for geometry, which is safe because
            // `usePresentationGeometry` already ruled out CameraUI layers in
            // this tree.
            guard let modelSublayers = layer.model().sublayers, !modelSublayers.isEmpty else { return }
            var safeSublayers: [(CALayer, String)] = []
            safeSublayers.reserveCapacity(modelSublayers.count)
            for sublayer in modelSublayers {
                let sublayerClassName = NSStringFromClass(type(of: sublayer))
                if !policy.shouldSkipLayer(className: sublayerClassName) {
                    safeSublayers.append((geometryLayer(for: sublayer), sublayerClassName))
                }
            }
            guard !safeSublayers.isEmpty else { return }
            if safeSublayers.count == 1 {
                visit(layer: safeSublayers[0].0, layerClassName: safeSublayers[0].1, inheritedExplicitMask: childInheritedMask)
            } else {
                safeSublayers.sorted { $0.0.zPosition < $1.0.zPosition }
                    .forEach { visit(layer: $0.0, layerClassName: $0.1, inheritedExplicitMask: childInheritedMask) }
            }
        }

        // Enumerate model sublayers at the root level for the same reason.
        let rootModelSublayers = rPresentation.model().sublayers ?? []
        var safeRootSublayers: [(CALayer, String)] = []
        safeRootSublayers.reserveCapacity(rootModelSublayers.count)
        for sublayer in rootModelSublayers {
            let sublayerClassName = NSStringFromClass(type(of: sublayer))
            if !policy.shouldSkipLayer(className: sublayerClassName) {
                safeRootSublayers.append((geometryLayer(for: sublayer), sublayerClassName))
            }
        }
        if !safeRootSublayers.isEmpty {
            if safeRootSublayers.count == 1 {
                visit(layer: safeRootSublayers[0].0, layerClassName: safeRootSublayers[0].1, inheritedExplicitMask: nil)
            } else {
                safeRootSublayers.sorted { $0.0.zPosition < $1.0.zPosition }
                    .forEach { visit(layer: $0.0, layerClassName: $0.1, inheritedExplicitMask: nil) }
            }
        }

        return (operations, offsetRects)
    }

    /// `true` when the model tree rooted at `root` contains a layer type that
    /// traps while Core Animation builds its presentation copy (the private
    /// `CameraUI` classes on iOS 26+). Only class identities and model
    /// sublayers are read, so the scan itself never asks for a presentation
    /// copy. The per-class memo keeps this to one `NSStringFromClass` per
    /// distinct layer class instead of one per layer.
    private func containsUnsafeLayer(_ root: CALayer) -> Bool {
        var unsafeByClass: [ObjectIdentifier: Bool] = [:]
        var stack: [CALayer] = [root.model()]
        stack.reserveCapacity(64)
        while let layer = stack.popLast() {
            let layerClass: AnyClass = type(of: layer)
            let key = ObjectIdentifier(layerClass)
            let isUnsafe: Bool
            if let cached = unsafeByClass[key] {
                isUnsafe = cached
            } else {
                isUnsafe = policy.shouldSkipLayer(className: NSStringFromClass(layerClass))
                unsafeByClass[key] = isUnsafe
            }
            if isUnsafe { return true }
            if let sublayers = layer.sublayers {
                stack.append(contentsOf: sublayers)
            }
        }
        return false
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
