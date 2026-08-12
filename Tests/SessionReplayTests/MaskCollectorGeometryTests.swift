import Testing
@testable import LaunchDarklySessionReplay
import UIKit

/// A stand-in for the private iOS 26 `CameraUI.ModeLoupeLayer`: the
/// `@objc` name gives it the `CameraUI` prefix `MaskingPolicy` matches on,
/// without needing the real (unavailable) class.
@objc(CameraUIFakeTestLayer)
final class CameraUIFakeTestLayer: CALayer {}

@MainActor
struct MaskCollectorGeometryTests {
    private struct Hierarchy {
        let window: UIWindow
        let container: UIView
        let label: UILabel
    }

    private func makeHierarchy() -> Hierarchy {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        let container = UIView(frame: window.bounds)
        window.addSubview(container)
        let label = UILabel(frame: CGRect(x: 50, y: 100, width: 100, height: 20))
        label.text = "secret"
        container.addSubview(label)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return Hierarchy(window: window, container: container, label: label)
    }

    /// Adds a rotation that lives only in the presentation layer: the model
    /// `transform` stays identity for the whole animation. Holding the same
    /// angle from start to finish keeps the expected value independent of
    /// when the assertion runs.
    private func addPresentationOnlyRotation(_ angle: CGFloat, to layer: CALayer) {
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = angle
        rotation.toValue = angle
        rotation.duration = 60
        layer.add(rotation, forKey: "rotation")
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

    private func affineTransform(of operation: MaskOperation) throws -> CGAffineTransform {
        guard case let .affine(_, transform) = operation.mask else {
            throw MaskShapeError.notAffine
        }
        return transform
    }

    private enum MaskShapeError: Error { case notAffine }

    @Test("a rotation applied to the view is reflected in the mask transform")
    func staticRotationIsMasked() async throws {
        let hierarchy = makeHierarchy()
        hierarchy.label.transform = CGAffineTransform(rotationAngle: .pi / 4)
        await waitForRenderCommit()

        let operations = collect(in: hierarchy.window)
        let transform = try affineTransform(of: try #require(operations.first))
        #expect(abs(transform.b - CGFloat(2).squareRoot() / 2) < 0.01)
        #expect(abs(transform.c + CGFloat(2).squareRoot() / 2) < 0.01)
    }

    @Test("a rotation driven only by a CAAnimation is reflected in the mask transform")
    func animatedRotationIsMasked() async throws {
        let hierarchy = makeHierarchy()
        addPresentationOnlyRotation(.pi / 4, to: hierarchy.label.layer)
        await waitForRenderCommit()

        // Precondition: the rotation exists only in the presentation layer.
        #expect(hierarchy.label.layer.transform.m12 == 0)

        let operations = collect(in: hierarchy.window)
        let transform = try affineTransform(of: try #require(operations.first))
        #expect(abs(transform.b - CGFloat(2).squareRoot() / 2) < 0.01)
        #expect(abs(transform.c + CGFloat(2).squareRoot() / 2) < 0.01)
    }

    @Test("an animated position change is reflected in the mask origin")
    func animatedPositionIsMasked() async throws {
        let hierarchy = makeHierarchy()
        let slide = CABasicAnimation(keyPath: "position.x")
        slide.fromValue = hierarchy.label.layer.position.x + 120
        slide.toValue = hierarchy.label.layer.position.x + 120
        slide.duration = 60
        hierarchy.label.layer.add(slide, forKey: "slide")
        await waitForRenderCommit()

        let operations = collect(in: hierarchy.window)
        let transform = try affineTransform(of: try #require(operations.first))
        #expect(abs(transform.tx - 170) < 0.01)
    }

    @Test("the mask covers the view's frame in points, without any render-scale factor")
    func maskGeometryIsInPointSpace() async throws {
        let hierarchy = makeHierarchy()
        await waitForRenderCommit()

        let operations = collect(in: hierarchy.window)
        let operation = try #require(operations.first)
        guard case let .affine(rect, transform) = operation.mask else {
            throw MaskShapeError.notAffine
        }

        // The capture context already carries the render scale in its CTM, so
        // the mask must land exactly on the label's point frame.
        let masked = rect.applying(transform)
        #expect(abs(masked.minX - hierarchy.label.frame.minX) < 0.01)
        #expect(abs(masked.minY - hierarchy.label.frame.minY) < 0.01)
        #expect(abs(masked.width - hierarchy.label.frame.width) < 0.01)
        #expect(abs(masked.height - hierarchy.label.frame.height) < 0.01)
    }

    @Test("a CameraUI layer in the tree forces model geometry instead of crashing")
    func cameraUILayerFallsBackToModelGeometry() async throws {
        let hierarchy = makeHierarchy()
        hierarchy.container.layer.addSublayer(CameraUIFakeTestLayer())
        addPresentationOnlyRotation(.pi / 4, to: hierarchy.label.layer)
        await waitForRenderCommit()

        let operations = collect(in: hierarchy.window)
        let transform = try affineTransform(of: try #require(operations.first))
        #expect(transform.b == 0)
        #expect(transform.c == 0)
    }
}
