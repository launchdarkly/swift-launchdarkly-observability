import Foundation
import LaunchDarklyObservability

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
        case .keyboard: return "keyboard"
        case .untrackedWindowTouch: return "untrackedWindowTouch"
        case .other: return "other"
        }
    }

    var sessionReplayUIPressTypeRawIfOther: Int? {
        if case .other(let raw) = self { return raw }
        return nil
    }

    /// Coarse device category for `RemoteControl` payloads (no hardware identifiers). Not used for ``KeyboardPressPayload``.
    var sessionReplayInputDevice: String {
        switch self {
        case .other:
            return "unknown"
        case .keyboard, .untrackedWindowTouch:
            return "unknown"
        default:
            return "siriRemote"
        }
    }
}
