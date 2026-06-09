import Foundation

/// An app-lifecycle analytics event broadcast to in-process consumers such as
/// Session Replay.
///
/// Drives both the taxonomy span (`app_foreground` / `app_background`) and the
/// Session Replay timeline breadcrumb (`Foreground` / `Background`). Mirrors
/// ``ScreenViewEvent`` / ``TrackEvent``.
///
/// Named distinctly from ``AppLifeCycleEvent`` (the raw UIKit lifecycle event) on
/// purpose: this is the taxonomy-level event derived from those raw transitions.
public struct AppLifecycleSignal: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case foreground
        case background
    }

    /// Which taxonomy lifecycle event this represents.
    public let kind: Kind
    /// The OTel-aligned lifecycle state.
    public let lifecycleState: String?
    /// Event time, in seconds since 1970.
    public let timestamp: TimeInterval

    public init(
        kind: Kind,
        lifecycleState: String? = nil,
        timestamp: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.kind = kind
        self.lifecycleState = lifecycleState
        self.timestamp = timestamp
    }
}
