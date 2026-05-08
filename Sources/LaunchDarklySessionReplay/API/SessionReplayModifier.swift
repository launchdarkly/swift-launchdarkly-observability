import SwiftUI
import UIKit

struct SessionReplayModifier: ViewModifier {
    let isEnabled: Bool?
    let isIgnored: Bool?
    
    public func body(content: Content) -> some View {
        content.overlay(
            SessionReplayViewRepresentable(isEnabled: isEnabled, isIgnored: isIgnored)
                .allowsHitTesting(false)
        )
    }
}

struct SessionReplayViewRepresentable: UIViewRepresentable {
    public typealias Context = UIViewRepresentableContext<Self>

    let isEnabled: Bool?
    let isIgnored: Bool?

    public init(isEnabled: Bool?, isIgnored: Bool?) {
        self.isEnabled = isEnabled
        self.isIgnored = isIgnored
    }

    /// Marker view inserted by `.ldMask()` / `.ldUnmask()` / `.ldIgnore()` /
    /// `.ldPrivate(...)` SwiftUI modifiers.
    ///
    /// Because `SessionReplayModifier` attaches itself via `.overlay()`, this
    /// view ends up as a *sibling* of the modified content in the UIKit
    /// hierarchy — not an ancestor. The view itself carries the explicit
    /// mask/ignore state via associated objects; `MaskCollector` then detects
    /// these markers at collection time, walks up to the lowest common
    /// ancestor of the overlay branch and the content branch, and propagates
    /// the explicit state to that ancestor so it reaches the modified
    /// content.
    class MaskView: UIView {
        // Tracks how many markers are currently attached to a window so
        // `MaskCollector` can skip its per-frame UIView walk entirely
        // when the running app uses no `.ldMask()` / `.ldUnmask()` /
        // `.ldIgnore()` modifiers.
        //
        // Mutated only on the main thread in `didMoveToWindow`. Reads
        // happen on the screen-capture queue; a stale read at worst
        // costs one frame of skipped/extra work, which is acceptable
        // because the next capture will see the corrected value.
        private static let liveMarkerLock = NSLock()
        private static var liveMarkerCount: Int = 0
        private var isCounted: Bool = false

        static var hasLiveMarkers: Bool {
            liveMarkerLock.lock()
            defer { liveMarkerLock.unlock() }
            return liveMarkerCount > 0
        }

        private static func incrementLiveMarkers() {
            liveMarkerLock.lock()
            liveMarkerCount += 1
            liveMarkerLock.unlock()
        }

        private static func decrementLiveMarkers() {
            liveMarkerLock.lock()
            liveMarkerCount = max(0, liveMarkerCount - 1)
            liveMarkerLock.unlock()
        }

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            // We want to make sure the wrapper view created by SwiftUI also doesn't intercept touches
            superview?.isUserInteractionEnabled = false
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            superview?.isUserInteractionEnabled = false

            let isAttached = window != nil
            if isAttached, !isCounted {
                isCounted = true
                Self.incrementLiveMarkers()
            } else if !isAttached, isCounted {
                isCounted = false
                Self.decrementLiveMarkers()
            }
        }

        deinit {
            if isCounted {
                Self.decrementLiveMarkers()
            }
        }

        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            return false
        }
    }

    public func makeUIView(context: Context) -> MaskView {
        let view = MaskView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    public func updateUIView(_ uiView: MaskView, context: Context) {
        if let isEnabled {
            SessionReplayAssociatedObjects.maskUIView(uiView, isEnabled: isEnabled)
        }
        if let isIgnored {
            SessionReplayAssociatedObjects.ignoreUIView(uiView, isEnabled: isIgnored)
        }
    }
}
