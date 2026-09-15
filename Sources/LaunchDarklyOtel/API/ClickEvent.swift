import Foundation

/// A click/tap broadcast to in-process consumers such as Session Replay.
///
/// Emitted by the single click emitter, ``ObservabilityService/recordClick(_:)``, for every click
/// path — automatic tap detection and the manual `trackClick` API. Session Replay maps these to
/// RRWeb `Click` custom events, mirroring the web SDK where each click emits
/// `addCustomEvent('Click', ...)`.
///
/// Embedders that render their own UI into a single native view (Flutter, which draws everything
/// into a `FlutterView`) resolve the target in their own widget tree and report it through
/// `trackClick`, so the same funnel serves both native and embedder-owned taps.
public struct ClickEvent: Sendable {
    /// Short element tag, e.g. `UIButton`.
    public let tag: String?
    /// Fully-qualified element class name, when known.
    public let classname: String?
    /// Stable element identifier (`ldId`, accessibility identifier, React Native `nativeID`).
    public let id: String?
    /// Visible text/label of the element, when known and not sensitive.
    public let text: String?
    /// Path of the element within its UI hierarchy, when known.
    public let xpath: String?
    /// Stable id of the screen the click landed on.
    public let screenId: String?
    /// Human-readable name of that screen, matching `screen_view`'s `event.name`.
    public let screenName: String?
    /// Click x coordinate, in points.
    public let x: Int?
    /// Click y coordinate, in points.
    public let y: Int?
    /// Capture time, in seconds since 1970.
    public let timestamp: TimeInterval
    /// When the gesture began, for callers that time the span across the whole press (automatic tap
    /// detection spans touch-down to touch-up). `nil` starts the span at ``timestamp``.
    public let startTimestamp: TimeInterval?

    public init(
        tag: String? = nil,
        classname: String? = nil,
        id: String? = nil,
        text: String? = nil,
        xpath: String? = nil,
        screenId: String? = nil,
        screenName: String? = nil,
        x: Int? = nil,
        y: Int? = nil,
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        startTimestamp: TimeInterval? = nil
    ) {
        self.tag = tag
        self.classname = classname
        self.id = id
        self.text = text
        self.xpath = xpath
        self.screenId = screenId
        self.screenName = screenName
        self.x = x
        self.y = y
        self.timestamp = timestamp
        self.startTimestamp = startTimestamp
    }
}
