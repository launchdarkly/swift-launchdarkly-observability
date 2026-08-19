#if os(iOS)
import SwiftUI
import UIKit

extension View {
    /// Presents `content` over the current screen with a cross-dissolve. `sheet` and `fullScreenCover`
    /// always slide in, so the presentation is bridged to UIKit to fade the cover in and out instead.
    ///
    /// - Parameters:
    ///   - isPresented: Drives the presentation; setting it back to `false` fades the cover out.
    ///   - opacity: How far the fade goes, from `0` (invisible) to `1` (fully opaque). Values below `1`
    ///     leave the cover translucent, so the presenting screen stays visible behind it.
    ///   - duration: Length of the fade, in seconds.
    func crossDissolveCover<Content: View>(
        isPresented: Binding<Bool>,
        opacity: Double = 1,
        duration: TimeInterval = 0.35,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        background(
            CrossDissolveCoverPresenter(
                isPresented: isPresented,
                opacity: opacity,
                duration: duration,
                content: content
            )
        )
    }
}

private struct CrossDissolveCoverPresenter<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let opacity: Double
    let duration: TimeInterval
    let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ presenter: UIViewController, context: Context) {
        let shouldPresent = isPresented
        let opacity = min(max(opacity, 0), 1)
        let duration = duration
        let content = content
        // Presenting from inside a SwiftUI update pass is not allowed, so hand it to the next runloop.
        DispatchQueue.main.async {
            context.coordinator.update(
                shouldPresent: shouldPresent,
                opacity: CGFloat(opacity),
                duration: duration,
                from: presenter,
                content: content
            )
        }
    }

    final class Coordinator {
        private let transition = FadeTransitioningDelegate()
        private weak var cover: UIViewController?

        func update(
            shouldPresent: Bool,
            opacity: CGFloat,
            duration: TimeInterval,
            from presenter: UIViewController,
            content: () -> Content
        ) {
            transition.opacity = opacity
            transition.duration = duration

            if shouldPresent, cover == nil, presenter.presentedViewController == nil {
                // The cover paints its own opaque background: `UIHostingController` owns the background
                // color of its view, so setting that from here is not reliable, and any translucency
                // should come from `opacity` alone rather than from gaps in the content.
                let cover = UIHostingController(
                    rootView: ZStack {
                        Color(.systemBackground).ignoresSafeArea()
                        content()
                    }
                )
                // `overFullScreen` leaves the presenter on screen, which is what turns the fade into a
                // real cross-dissolve rather than a fade up from black.
                cover.modalPresentationStyle = .overFullScreen
                cover.transitioningDelegate = transition
                self.cover = cover
                presenter.present(cover, animated: true)
            } else if !shouldPresent, let cover = cover {
                self.cover = nil
                cover.presentingViewController?.dismiss(animated: true)
            }
        }
    }
}

/// UIKit's built-in `.crossDissolve` can leave the cover stranded part-way through the fade when the
/// render transaction is flushed mid-animation, which session replay's frame capture does. Animating
/// the alpha here keeps the end state authoritative: it is the model value, and it is re-applied when
/// the animation completes, so an interrupted fade still settles on the requested opacity.
private final class FadeTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    var opacity: CGFloat = 1
    var duration: TimeInterval = 0.35

    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        FadeAnimator(isPresenting: true, targetAlpha: opacity, duration: duration)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        FadeAnimator(isPresenting: false, targetAlpha: 0, duration: duration)
    }
}

private final class FadeAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let isPresenting: Bool
    private let targetAlpha: CGFloat
    private let duration: TimeInterval

    init(isPresenting: Bool, targetAlpha: CGFloat, duration: TimeInterval) {
        self.isPresenting = isPresenting
        self.targetAlpha = targetAlpha
        self.duration = duration
        super.init()
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        duration
    }

    func animateTransition(using context: UIViewControllerContextTransitioning) {
        if isPresenting {
            guard let controller = context.viewController(forKey: .to),
                  let cover = context.view(forKey: .to) else {
                context.completeTransition(false)
                return
            }
            let finalFrame = context.finalFrame(for: controller)
            cover.frame = finalFrame.isEmpty ? context.containerView.bounds : finalFrame
            cover.alpha = 0
            context.containerView.addSubview(cover)

            animate({ cover.alpha = self.targetAlpha }, then: {
                cover.alpha = self.targetAlpha
                context.completeTransition(!context.transitionWasCancelled)
            })
        } else {
            guard let cover = context.view(forKey: .from) else {
                context.completeTransition(false)
                return
            }

            animate({ cover.alpha = self.targetAlpha }, then: {
                cover.removeFromSuperview()
                context.completeTransition(!context.transitionWasCancelled)
            })
        }
    }

    private func animate(_ animations: @escaping () -> Void, then completion: @escaping () -> Void) {
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState],
            animations: animations,
            completion: { _ in completion() }
        )
    }
}
#endif
