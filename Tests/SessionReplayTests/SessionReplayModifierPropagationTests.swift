import Testing
@testable import LaunchDarklySessionReplay
import SwiftUI
import UIKit

/// Verifies that SwiftUI's `.ldMask()` / `.ldUnmask()` / `.ldIgnore()`
/// modifiers — which insert their marker view via `.overlay()` and
/// therefore land as a *sibling* of the modified content (in the
/// simplest case) or even completely disjoint from it (when SwiftUI
/// renders content directly into a CALayer on iOS 26 Liquid Glass) —
/// still affect the modified content.
///
/// `MaskCollector` does this by recording each marker's frame in the
/// root layer's coordinate space (a `MarkerArea`) and, during the visit
/// pass, applying the marker's explicit state to any layer/view whose
/// frame is contained inside it. That works regardless of whether the
/// modified content is a sibling, a deeply nested descendant, or a pure
/// CALayer.
@MainActor
struct SessionReplayModifierPropagationTests {
    typealias MaskView = SessionReplayViewRepresentable.MaskView

    /// Mimics the simplest SwiftUI shape: an overlay branch and a
    /// content branch sharing the same multi-child host with equal
    /// frames. The content branch is fully contained within the
    /// marker's projected area.
    private func makeOverlayHierarchy() -> (window: UIWindow, contentBranch: UIView, mask: MaskView) {
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 200)
        let window = UIWindow(frame: bounds)
        let commonHost = UIView(frame: bounds)
        let contentBranch = UIView(frame: bounds)
        let overlayBranch = UIView(frame: bounds)
        let representableHost = UIView(frame: bounds)
        let mask = MaskView(frame: bounds)

        commonHost.addSubview(contentBranch)
        commonHost.addSubview(overlayBranch)
        overlayBranch.addSubview(representableHost)
        representableHost.addSubview(mask)

        window.addSubview(commonHost)
        window.isHidden = false
        window.layoutIfNeeded()

        return (window, contentBranch, mask)
    }

    // MARK: - computeMarkerAreas

    @Test("computeMarkerAreasAndOverlayBranches projects each marker into root-layer coordinates with the developer's explicit state")
    func computeMarkerAreasProjectsToRoot() {
        let (window, _, mask) = makeOverlayHierarchy()
        SessionReplayAssociatedObjects.maskUIView(mask, isEnabled: false)

        let collector = MaskCollector(privacySettings: .init(maskTextInputs: false))
        let (areas, overlayBranchViews) = collector.computeMarkerAreasAndOverlayBranches(in: window, rPresentation: window.layer)
        #expect(areas.count == 1)
        #expect(areas.first?.mask == false)
        #expect(areas.first?.ignore == nil)
        #expect(areas.first?.frameInRoot.equalTo(CGRect(x: 0, y: 0, width: 200, height: 200)) == true)
        // The overlay branch wrapper chain must include at least the
        // marker view itself.
        #expect(overlayBranchViews.contains(ObjectIdentifier(mask)))
    }

    @Test("computeMarkerAreasAndOverlayBranches records ignore=true for an .ldIgnore() marker")
    func computeMarkerAreasIgnore() {
        let (window, _, mask) = makeOverlayHierarchy()
        SessionReplayAssociatedObjects.ignoreUIView(mask, isEnabled: true)

        let collector = MaskCollector(privacySettings: .init(maskTextInputs: false))
        let (areas, _) = collector.computeMarkerAreasAndOverlayBranches(in: window, rPresentation: window.layer)
        #expect(areas.count == 1)
        #expect(areas.first?.ignore == true)
    }

    @Test("computeMarkerAreasAndOverlayBranches skips MaskView instances that are detached from the window")
    func computeMarkerAreasSkipsDetached() {
        let detachedHost = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let mask = MaskView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        detachedHost.addSubview(mask)
        SessionReplayAssociatedObjects.maskUIView(mask, isEnabled: true)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let attached = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        window.addSubview(attached)
        window.isHidden = false
        window.layoutIfNeeded()

        let collector = MaskCollector(privacySettings: .init(maskTextInputs: false))
        let (areas, _) = collector.computeMarkerAreasAndOverlayBranches(in: window, rPresentation: window.layer)
        #expect(areas.isEmpty)
    }

    @Test("computeMarkerAreasAndOverlayBranches stops at a single-child host whose bounds exceed the marker's")
    func computeMarkerAreasStopsAtLargerSingleChildHost() {
        // Reproduces the live MainMenuView shape on iOS 26: the marker
        // wrappers end inside a `CellHostingView`-equivalent that has
        // exactly one subview (the wrapper chain) but is much larger
        // than the marker because it owns the cell's rendered content
        // as sublayers. We must NOT treat that host as part of the
        // overlay branch — otherwise `visit` would short-circuit there
        // and never reach the real content.
        let cellContent = UIView(frame: CGRect(x: 0, y: 0, width: 370, height: 64))
        let markerWrapper = UIView(frame: CGRect(x: 16, y: 22, width: 105, height: 20))
        let mask = MaskView(frame: CGRect(x: 0, y: 0, width: 105, height: 20))
        markerWrapper.addSubview(mask)
        cellContent.addSubview(markerWrapper)

        let cellHost = UIView(frame: CGRect(x: 0, y: 0, width: 370, height: 64))
        cellHost.addSubview(cellContent)

        // Force the chain above `cellHost` to be a single-child chain
        // too, mimicking iOS 26's `_UICollectionViewListCellContentView`
        // → `ListCollectionViewCell` shape.
        let outerWrapper = UIView(frame: CGRect(x: 0, y: 0, width: 370, height: 64))
        outerWrapper.addSubview(cellHost)

        let multiChildAncestor = UIView(frame: CGRect(x: 0, y: 0, width: 370, height: 200))
        let unrelatedSibling = UIView(frame: CGRect(x: 0, y: 100, width: 370, height: 100))
        multiChildAncestor.addSubview(outerWrapper)
        multiChildAncestor.addSubview(unrelatedSibling)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        window.addSubview(multiChildAncestor)
        window.isHidden = false
        window.layoutIfNeeded()

        SessionReplayAssociatedObjects.maskUIView(mask, isEnabled: true)

        let collector = MaskCollector(privacySettings: .init(maskTextInputs: false))
        let (_, overlayBranchViews) = collector.computeMarkerAreasAndOverlayBranches(in: window, rPresentation: window.layer)

        // Overlay-branch chain stops at the marker wrapper because
        // `cellContent` is much larger than the marker.
        #expect(overlayBranchViews.contains(ObjectIdentifier(mask)))
        #expect(overlayBranchViews.contains(ObjectIdentifier(markerWrapper)))
        #expect(!overlayBranchViews.contains(ObjectIdentifier(cellContent)))
        #expect(!overlayBranchViews.contains(ObjectIdentifier(cellHost)))
        #expect(!overlayBranchViews.contains(ObjectIdentifier(outerWrapper)))
    }

    @Test("End-to-end: a label sublayer inside a single-child host larger than the marker is masked")
    func collectorMasksLabelInLargerSingleChildHost() {
        // End-to-end version of the failure that hit the live
        // MainMenuView: the only direct subview of the host is the
        // marker wrapper, but the host's actual content (a label here)
        // is rendered as a sibling sublayer/subview. Without the size
        // check, the host would be classified as part of the overlay
        // branch and the label would never be visited.
        let cellHost = UIView(frame: CGRect(x: 0, y: 0, width: 370, height: 64))

        let label = UILabel(frame: CGRect(x: 16, y: 22, width: 105, height: 20))
        label.text = "title"

        let markerWrapper = UIView(frame: CGRect(x: 16, y: 22, width: 105, height: 20))
        let mask = MaskView(frame: CGRect(x: 0, y: 0, width: 105, height: 20))
        markerWrapper.addSubview(mask)

        // Two subviews keeps `cellHost` from looking like a wrapper
        // even with the looser old heuristic; the regression is about
        // the chain *above* `cellHost`, which now stays single-child.
        cellHost.addSubview(label)
        cellHost.addSubview(markerWrapper)

        // Single-child chain above `cellHost` mirrors
        // `_UICollectionViewListCellContentView` → `CellHostingView`.
        let contentWrapper = UIView(frame: CGRect(x: 0, y: 0, width: 370, height: 64))
        contentWrapper.addSubview(cellHost)
        let cell = UIView(frame: CGRect(x: 16, y: 48, width: 370, height: 64))
        cell.addSubview(contentWrapper)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 200))
        window.addSubview(cell)
        window.isHidden = false
        window.layoutIfNeeded()

        SessionReplayAssociatedObjects.maskUIView(mask, isEnabled: true)

        let collector = MaskCollector(privacySettings: .init(maskTextInputs: false, maskLabels: false))
        let result = collector.collectViewMasks(in: window, window: window, scale: 1)

        // Exactly one mask op covering the label — the cell, content
        // wrapper, and host must remain unmasked even though they sit
        // on the path between the marker and the multi-child ancestor.
        #expect(result.maskOperations.count == 1)
    }

    @Test("computeMarkerAreasAndOverlayBranches collects the single-child wrapper chain above each marker")
    func computeMarkerAreasCollectsOverlayChain() {
        // Wrappers with one child each above the MaskView form the
        // overlay branch and must be skipped during the visit pass to
        // avoid duplicate mask ops.
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let outerWrapper = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let innerWrapper = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let mask = MaskView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        innerWrapper.addSubview(mask)
        outerWrapper.addSubview(innerWrapper)
        // A second sibling at this level ensures the chain stops at
        // `host` (the first multi-child ancestor).
        let unrelatedSibling = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        host.addSubview(unrelatedSibling)
        host.addSubview(outerWrapper)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        window.addSubview(host)
        window.isHidden = false
        window.layoutIfNeeded()

        SessionReplayAssociatedObjects.maskUIView(mask, isEnabled: true)

        let collector = MaskCollector(privacySettings: .init(maskTextInputs: false))
        let (_, overlayBranchViews) = collector.computeMarkerAreasAndOverlayBranches(in: window, rPresentation: window.layer)

        #expect(overlayBranchViews.contains(ObjectIdentifier(mask)))
        #expect(overlayBranchViews.contains(ObjectIdentifier(innerWrapper)))
        #expect(overlayBranchViews.contains(ObjectIdentifier(outerWrapper)))
        #expect(!overlayBranchViews.contains(ObjectIdentifier(host)))
        #expect(!overlayBranchViews.contains(ObjectIdentifier(unrelatedSibling)))
    }

    @Test("MarkerOverride.combine: mask=true beats mask=false on the same area")
    func combineMaskPrecedence() {
        var override = MaskCollector.MarkerOverride()
        override.combine(mask: false, ignore: nil)
        override.combine(mask: true, ignore: nil)
        #expect(override.mask == true)

        var override2 = MaskCollector.MarkerOverride()
        override2.combine(mask: true, ignore: nil)
        override2.combine(mask: false, ignore: nil)
        #expect(override2.mask == true)
    }

    // MARK: - End-to-end through MaskCollector.collectViewMasks

    @Test("End-to-end: a globally-masked TextInput inside an .ldUnmask() SwiftUI marker is not masked (sibling shape)")
    func collectorRespectsAncestorUnmaskFromSwiftUIModifier() {
        let (window, contentBranch, mask) = makeOverlayHierarchy()

        let textField = UITextField(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        contentBranch.addSubview(textField)

        SessionReplayAssociatedObjects.maskUIView(mask, isEnabled: false)
        window.layoutIfNeeded()

        let collector = MaskCollector(privacySettings: .init(maskTextInputs: true))
        let result = collector.collectViewMasks(in: window, window: window, scale: 1)

        // Without propagation, `maskTextInputs=true` would have masked
        // the text field. The marker's `unmask` area covers the text
        // field, so it stays visible.
        #expect(result.maskOperations.isEmpty)
    }

    @Test("End-to-end: a flattened TextInput sibling inside an .ldUnmask() marker area is not masked")
    func collectorUnmasksFlattenedTextFieldSibling() {
        // Reproduces the live TestApp shape: SwiftUI flattens the
        // `.ldUnmask()`-decorated VStack so the inner TextField is a
        // smaller sibling of the overlay branch, contained within the
        // marker's frame.
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 569))
        let textField = UITextField(frame: CGRect(x: 24, y: 191, width: 354, height: 34))
        let overlayBranch = UIView(frame: CGRect(x: 16, y: 183, width: 370, height: 50))
        let representableHost = UIView(frame: CGRect(x: 0, y: 0, width: 370, height: 50))
        let mask = MaskView(frame: CGRect(x: 0, y: 0, width: 370, height: 50))

        host.addSubview(textField)
        host.addSubview(overlayBranch)
        overlayBranch.addSubview(representableHost)
        representableHost.addSubview(mask)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 600))
        window.addSubview(host)
        window.isHidden = false
        window.layoutIfNeeded()

        SessionReplayAssociatedObjects.maskUIView(mask, isEnabled: false)

        let collector = MaskCollector(privacySettings: .init(maskTextInputs: true))
        let result = collector.collectViewMasks(in: window, window: window, scale: 1)

        // The text field's frame in root coords (24, 191, 354, 34) is
        // inside the marker's area (16, 183, 370, 50), so it inherits
        // mask=false and stays visible despite `maskTextInputs=true`.
        #expect(result.maskOperations.isEmpty)
    }

    @Test("End-to-end: a deeply-nested label inside an .ldMask() marker area is masked even with maskLabels=false")
    func collectorMasksDeeplyNestedLabel() {
        // Reproduces the iOS 26 + List-row shape: the marker is the
        // *only* direct subview of an outer hosting cell that's much
        // larger than the marker itself, with the actual label sitting
        // somewhere inside that hosting cell at the marker's position.
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
        let window = UIWindow(frame: bounds)

        // Cell-row layout: a system-background sibling at the row's
        // full size next to the cell hosting view that contains the
        // label and the marker. The system background must NOT get
        // masked just because it overlaps the marker on screen.
        let outer = UIView(frame: bounds)
        let cellBackground = UIView(frame: CGRect(x: 0, y: 50, width: 400, height: 80))
        let cellHostingView = UIView(frame: CGRect(x: 0, y: 50, width: 400, height: 80))
        let label = UILabel(frame: CGRect(x: 16, y: 22, width: 105, height: 20))
        label.text = "title"
        let overlayBranch = UIView(frame: CGRect(x: 16, y: 22, width: 105, height: 20))
        let representableHost = UIView(frame: CGRect(x: 0, y: 0, width: 105, height: 20))
        let mask = MaskView(frame: CGRect(x: 0, y: 0, width: 105, height: 20))

        cellHostingView.addSubview(label)
        cellHostingView.addSubview(overlayBranch)
        overlayBranch.addSubview(representableHost)
        representableHost.addSubview(mask)
        outer.addSubview(cellBackground)
        outer.addSubview(cellHostingView)
        window.addSubview(outer)
        window.isHidden = false
        window.layoutIfNeeded()

        SessionReplayAssociatedObjects.maskUIView(mask, isEnabled: true)

        let collector = MaskCollector(privacySettings: .init(maskTextInputs: false, maskLabels: false))
        let result = collector.collectViewMasks(in: window, window: window, scale: 1)

        // Exactly one mask op covering the label — the cell background
        // (much larger than the marker area) must remain unmasked.
        #expect(result.maskOperations.count == 1)
        if let op = result.maskOperations.first {
            #expect(op.effectiveFrame.equalTo(CGRect(x: 16, y: 72, width: 105, height: 20)))
        }
    }

    @Test("End-to-end: an .ldMask() marker on a single Text in an HStack masks only that Text, not the buttons")
    func collectorMasksOnlyTextInHStack() {
        // The exact failure mode the user reported: `.ldMask()` on a
        // `Text` in an HStack alongside two buttons must mask only the
        // text column, not the buttons or the row background.
        let bounds = CGRect(x: 0, y: 0, width: 360, height: 60)
        let window = UIWindow(frame: bounds)
        let row = UIView(frame: bounds)
        let textColumn = UILabel(frame: CGRect(x: 0, y: 20, width: 100, height: 20))
        textColumn.text = "title"
        let buttonOne = UIButton(frame: CGRect(x: 120, y: 15, width: 100, height: 30))
        let buttonTwo = UIButton(frame: CGRect(x: 240, y: 15, width: 100, height: 30))
        let overlayBranch = UIView(frame: CGRect(x: 0, y: 20, width: 100, height: 20))
        let representableHost = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
        let mask = MaskView(frame: CGRect(x: 0, y: 0, width: 100, height: 20))

        row.addSubview(textColumn)
        row.addSubview(buttonOne)
        row.addSubview(buttonTwo)
        row.addSubview(overlayBranch)
        overlayBranch.addSubview(representableHost)
        representableHost.addSubview(mask)
        window.addSubview(row)
        window.isHidden = false
        window.layoutIfNeeded()

        SessionReplayAssociatedObjects.maskUIView(mask, isEnabled: true)

        let collector = MaskCollector(privacySettings: .init(maskTextInputs: false, maskLabels: false))
        let result = collector.collectViewMasks(in: window, window: window, scale: 1)

        #expect(result.maskOperations.count == 1)
        if let op = result.maskOperations.first {
            #expect(op.effectiveFrame.equalTo(textColumn.frame))
        }
    }

    @Test("End-to-end: a Text label inside an .ldMask() SwiftUI marker is masked even with maskLabels=false")
    func collectorRespectsAncestorMaskFromSwiftUIModifier() {
        let (window, contentBranch, mask) = makeOverlayHierarchy()

        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        contentBranch.addSubview(label)

        SessionReplayAssociatedObjects.maskUIView(mask, isEnabled: true)
        window.layoutIfNeeded()

        let collector = MaskCollector(privacySettings: .init(maskTextInputs: false, maskLabels: false))
        let result = collector.collectViewMasks(in: window, window: window, scale: 1)

        // The marker's `mask` area covers the content sibling, so the
        // label inside it is masked.
        #expect(result.maskOperations.isEmpty == false)
    }

    @Test("End-to-end: a TextInput inside an .ldIgnore() SwiftUI marker is skipped entirely")
    func collectorSkipsIgnoredSwiftUIMarker() {
        let (window, contentBranch, mask) = makeOverlayHierarchy()

        let textField = UITextField(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        contentBranch.addSubview(textField)

        SessionReplayAssociatedObjects.ignoreUIView(mask, isEnabled: true)
        window.layoutIfNeeded()

        let collector = MaskCollector(privacySettings: .init(maskTextInputs: true))
        let result = collector.collectViewMasks(in: window, window: window, scale: 1)

        // The marker's `ignore` area covers the text field; visit
        // skips it entirely.
        #expect(result.maskOperations.isEmpty)
    }

    @Test("End-to-end: a baseline TextInput with no marker is still masked when maskTextInputs=true")
    func collectorMasksTextInputWithoutModifier() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        let textField = UITextField(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        host.addSubview(textField)
        window.addSubview(host)
        window.isHidden = false
        window.layoutIfNeeded()

        let collector = MaskCollector(privacySettings: .init(maskTextInputs: true))
        let result = collector.collectViewMasks(in: window, window: window, scale: 1)

        // Sanity baseline: when no SwiftUI marker is present,
        // `maskTextInputs` still masks the field.
        #expect(result.maskOperations.count == 1)
    }
}
