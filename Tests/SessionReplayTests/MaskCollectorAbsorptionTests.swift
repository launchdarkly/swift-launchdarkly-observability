import Testing
@testable import LaunchDarklySessionReplay
import UIKit

/// An opaque view covering the screen absorbs the masks it hides, because nothing behind it is
/// visible in the captured frame. These tests pin down when that absorption must *not* happen: while
/// a screen is fading in, or while it stays translucent, the content behind it is still on display
/// and its masks have to survive.
@MainActor
struct MaskCollectorAbsorptionTests {
    private struct Hierarchy {
        let window: UIWindow
        let label: UILabel
        let cover: UIView
    }

    /// A masked label with an opaque, screen-filling view over it — the shape of a modal presented
    /// over a screen that has something to hide.
    private func makeHierarchy(coverNestedIn wrapper: UIView? = nil) -> Hierarchy {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        let label = UILabel(frame: CGRect(x: 50, y: 100, width: 100, height: 20))
        label.text = "secret"
        window.addSubview(label)

        let cover = UIView(frame: window.bounds)
        cover.backgroundColor = .white
        if let wrapper {
            wrapper.frame = window.bounds
            window.addSubview(wrapper)
            wrapper.addSubview(cover)
        } else {
            window.addSubview(cover)
        }

        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return Hierarchy(window: window, label: label, cover: cover)
    }

    /// Runs an opacity animation that holds the same value from start to finish, so neither the model
    /// layer nor the presentation layer reports anything but a fully opaque cover. Only the presence
    /// of the animation says the cover is still being blended over the screen behind it — which is the
    /// state a capture lands in before Core Animation has committed the fade's interpolated values.
    private func addHeldOpacityAnimation(to layer: CALayer) {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 1
        fade.duration = 60
        layer.add(fade, forKey: "opacity")
    }

    private func waitForRenderCommit() async {
        CATransaction.flush()
        try? await Task.sleep(nanoseconds: 200_000_000)
        CATransaction.flush()
    }

    private func collect(in window: UIWindow) -> [MaskOperation] {
        let collector = MaskCollector(privacySettings: .init(maskTextInputs: false, maskLabels: true))
        return collector.collectViewMasks(in: window, window: window).maskOperations
    }

    @Test("an opaque cover absorbs the masks it hides")
    func opaqueCoverAbsorbsMasks() async throws {
        let hierarchy = makeHierarchy()
        await waitForRenderCommit()

        #expect(collect(in: hierarchy.window).isEmpty)
    }

    @Test("a cover whose opacity is animating keeps the masks behind it")
    func fadingCoverKeepsMasks() async throws {
        let hierarchy = makeHierarchy()
        addHeldOpacityAnimation(to: hierarchy.cover.layer)
        await waitForRenderCommit()

        // Precondition: nothing but the running animation hints at the fade.
        #expect(hierarchy.cover.layer.opacity == 1)
        #expect(hierarchy.cover.layer.presentation()?.opacity ?? 1 == 1)

        #expect(collect(in: hierarchy.window).count == 1)
    }

    @Test("a cover keeps the masks behind it while an ancestor's opacity is animating")
    func fadingAncestorKeepsMasks() async throws {
        // UIKit fades a container view rather than the screen itself for presentations and pushes, so
        // the opaque view is nested one level down from the animation.
        let container = UIView()
        let hierarchy = makeHierarchy(coverNestedIn: container)
        addHeldOpacityAnimation(to: container.layer)
        await waitForRenderCommit()

        #expect(collect(in: hierarchy.window).count == 1)
    }

    @Test("a translucent cover keeps the masks behind it")
    func translucentCoverKeepsMasks() async throws {
        let hierarchy = makeHierarchy()
        hierarchy.cover.alpha = 0.5
        await waitForRenderCommit()

        #expect(collect(in: hierarchy.window).count == 1)
    }

    @Test("a cover keeps the masks behind it while a translucent ancestor is on screen")
    func translucentAncestorKeepsMasks() async throws {
        let container = UIView()
        let hierarchy = makeHierarchy(coverNestedIn: container)
        container.alpha = 0.5
        await waitForRenderCommit()

        #expect(collect(in: hierarchy.window).count == 1)
    }
}
