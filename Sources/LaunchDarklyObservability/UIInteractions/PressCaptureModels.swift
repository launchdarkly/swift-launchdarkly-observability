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
    /// `UITouch` on a window skipped by `UIEventReceiverChecker` (e.g. keyboard chrome), recorded without coordinates.
    case untrackedWindowTouch
}

/// A `UIPress` that is not mapped through the spatial `TouchSample` → `TouchInteraction` path (e.g. Menu, D-pad, hardware keyboard),
/// or a touch on a filtered window encoded for replay without pointer coordinates.
public struct PressInteraction: Sendable {
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

    init(phase: Phase, kind: RemotePressKind, timestamp: TimeInterval, target: TouchTarget?, isKeyboardOriginated: Bool) {
        self.phase = phase
        self.kind = kind
        self.timestamp = timestamp
        self.target = target
        self.isKeyboardOriginated = isKeyboardOriginated
    }

    init(touch: UITouch, target: TouchTarget?) {
        self.phase = Self.phase(forTouch: touch.phase)
        self.kind = .untrackedWindowTouch
        self.timestamp = touch.timestamp
        self.target = target
        self.isKeyboardOriginated = false
    }

    private static func phase(forTouch touchPhase: UITouch.Phase) -> Phase {
        switch touchPhase {
        case .began: return .began
        case .moved: return .changed
        case .ended: return .ended
        case .cancelled: return .cancelled
        case .stationary: return .stationary
        @unknown default: return .changed
        }
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

/// Touch and press interactions forwarded in order for session replay export.
public enum InteractionEvent: Sendable {
    case touch(TouchInteraction)
    case press(PressInteraction)
}

#endif
