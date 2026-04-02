import Foundation
import LaunchDarklyObservability

extension PressInteraction.Phase {
    var sessionReplayWirePhase: String {
        switch self {
        case .began: return "began"
        case .changed: return "changed"
        case .ended: return "ended"
        case .cancelled: return "cancelled"
        case .stationary: return "stationary"
        }
    }
}

extension RemotePressKind {
    var sessionReplayWirePressType: String {
        switch self {
        case .upArrow: return "upArrow"
        case .downArrow: return "downArrow"
        case .leftArrow: return "leftArrow"
        case .rightArrow: return "rightArrow"
        case .select: return "select"
        case .menu: return "menu"
        case .playPause: return "playPause"
        case .pageUp: return "pageUp"
        case .pageDown: return "pageDown"
        case .tvRemoteOneTwoThree: return "tvRemoteOneTwoThree"
        case .tvRemoteFourColors: return "tvRemoteFourColors"
        case .other: return "other"
        case .untrackedWindowTouch: return "untrackedWindowTouch"
        }
    }

    var sessionReplayUIPressTypeRawIfOther: Int? {
        if case .other(let raw) = self { return raw }
        return nil
    }
}
