#if canImport(UIKit)
import UIKit

/// Normalized remote / hardware button identity for presses that do not use window coordinates in replay.
public enum RemotePressKind: Sendable, Equatable {
    case upArrow
    case downArrow
    case leftArrow
    case rightArrow
    case select
    case menu
    case playPause
    case pageUp
    case pageDown
    case tvRemoteOneTwoThree
    case tvRemoteFourColors
    /// Press types introduced after this SDK (see `UIPress.PressType.rawValue`).
    case other(rawValue: Int)
}

/// A `UIPress` that is not mapped through the spatial `TouchSample` → `TouchInteraction` path (e.g. Menu, D-pad, hardware keyboard).
public struct NonCoordinatePressSample: Sendable {
    public enum Phase: Sendable {
        case began
        case changed
        case ended
        case cancelled
        case stationary
    }

    public let phase: Phase
    public let kind: RemotePressKind
    public let timestamp: TimeInterval
    public let target: TouchTarget?
    /// `true` when the press came from a hardware keyboard (`UIPress.key`); does not expose key contents.
    public let isKeyboardOriginated: Bool

    init(press: UIPress, target: TouchTarget?) {
        self.phase = Self.phase(for: press.phase)
        self.kind = RemotePressKind(pressType: press.type)
        self.timestamp = press.timestamp
        self.target = target
        self.isKeyboardOriginated = press.key != nil
    }

    private static func phase(for pressPhase: UIPress.Phase) -> Phase {
        switch pressPhase {
        case .began: return .began
        case .changed: return .changed
        case .ended: return .ended
        case .cancelled: return .cancelled
        case .stationary: return .stationary
        @unknown default: return .changed
        }
    }
}

extension RemotePressKind {
    init(pressType: UIPress.PressType) {
        switch pressType {
        case .upArrow: self = .upArrow
        case .downArrow: self = .downArrow
        case .leftArrow: self = .leftArrow
        case .rightArrow: self = .rightArrow
        case .select: self = .select
        case .menu: self = .menu
        case .playPause: self = .playPause
        #if os(tvOS)
        case .pageUp: self = .pageUp
        case .pageDown: self = .pageDown
        case .tvRemoteOneTwoThree: self = .tvRemoteOneTwoThree
        case .tvRemoteFourColors: self = .tvRemoteFourColors
        #endif
        @unknown default:
            self = .other(rawValue: pressType.rawValue)
        }
    }
}

extension UIPress {
    /// Maps through `TouchSample` / `TouchInteraction` when we can attribute a window point (tvOS Siri Remote touch surface uses `.select`).
    /// Public UIKit does not expose `UIPress.location(in:)` in Swift; spatial samples use the responder view center instead.
    /// On iOS, physical/game-controller/keyboard presses use `NonCoordinatePressSample` only.
    var usesSpatialCoordinatesForReplay: Bool {
        #if os(tvOS)
        if key != nil { return false }
        return type == .select
        #else
        return false
        #endif
    }
}

/// Window-space point for press hit testing / touch replay when `UIPress.location(in:)` is not available to Swift.
enum PressWindowGeometry {
    static func windowPoint(for press: UIPress, in window: UIWindow) -> CGPoint {
        if let view = press.responder as? UIView {
            let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            return view.convert(center, to: window)
        }
        return CGPoint(x: window.bounds.midX, y: window.bounds.midY)
    }
}

#endif
