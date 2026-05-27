#if canImport(UIKit)
import UIKit

/// Normalized identity for presses that do not use window coordinates in replay.
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
    /// Hardware keyboard key press (`UIPress.key != nil`). No key code or text is stored (privacy).
    case keyboard
    /// `UITouch` on a window skipped by `UIEventReceiverChecker` (e.g. keyboard chrome), recorded without coordinates.
    case untrackedWindowTouch
    /// Press types introduced after this SDK that are not keyboard-originated (see `UIPress.PressType.rawValue`).
    case other(rawValue: Int)
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
        case unknown
    }

    public let phase: Phase
    public let kind: RemotePressKind
    public let timestamp: TimeInterval
    public let target: TouchTarget?
    public let sessionId: String

    public var isKeyboard: Bool {
        kind == .keyboard || kind == .untrackedWindowTouch
    }

    init(press: UIPress, target: TouchTarget?, sessionId: String) {
        self.phase = Self.phase(for: press.phase)
        self.kind = press.key != nil ? .keyboard : RemotePressKind(pressType: press.type)
        self.timestamp = press.timestamp
        self.target = target
        self.sessionId = sessionId
    }

    init(phase: Phase, kind: RemotePressKind = .untrackedWindowTouch, timestamp: TimeInterval, target: TouchTarget?, sessionId: String) {
        self.phase = phase
        self.kind = kind
        self.timestamp = timestamp
        self.target = target
        self.sessionId = sessionId
    }

    static func phase(forTouch touchPhase: UITouch.Phase) -> Phase {
        switch touchPhase {
        case .began: return .began
        case .moved: return .changed
        case .ended: return .ended
        case .cancelled: return .cancelled
        case .stationary: return .stationary
        case .regionEntered: return .unknown
        case .regionMoved: return .unknown
        case .regionExited: return .unknown
        @unknown default: return .unknown
        }
    }

    private static func phase(for pressPhase: UIPress.Phase) -> Phase {
        switch pressPhase {
        case .began: return .began
        case .changed: return .changed
        case .ended: return .ended
        case .cancelled: return .cancelled
        case .stationary: return .stationary
        @unknown default: return .unknown
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
