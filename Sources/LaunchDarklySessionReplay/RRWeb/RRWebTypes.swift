import Foundation

enum EventType: Int, Codable {
    case DomContentLoaded = 0,
         Load = 1,
         FullSnapshot = 2,
         IncrementalSnapshot = 3,
         Meta = 4,
         Custom = 5,
         Plugin = 6
}

enum NodeType: Int, Codable {
    case Document = 0,
         DocumentType = 1,
         Element = 2,
         Text = 3,
         CDATA = 4,
         Comment = 5
}

enum IncrementalSource: Int, Codable {
    case mutation = 0,
         mouseMove = 1,
         mouseInteraction = 2,
         scroll = 3,
         viewportResize = 4,
         input = 5,
         touchMove = 6,
         mediaInteraction = 7,
         styleSheetRule = 8,
         canvasMutation = 9,
         font = 10,
         log = 11,
         drag = 12,
         styleDeclaration = 13,
         selection = 14,
         adoptedStyleSheet,
         customElement
}

enum MouseInteractions: Int, Codable {
    case mouseUp = 0,
         mouseDown = 1,
         click = 2,
         contextMenu = 3,
         dblClick = 4,
         focus = 5,
         blur = 6,
         touchStart = 7,
         touchMove_Departed = 8,
         touchEnd = 9,
         touchCancel = 10
}

/// Custom event `tag` strings on RRWeb `EventType.custom` payloads.
///
/// **Player / backend contract**
/// - Tags and JSON payload shapes below are the integration surface for the session replay web player and GraphQL ingestion.
/// - Ingestion that allowlists `tag` must include any tag you rely on; unknown tags should be stored opaquely or ignored per product policy.
/// - The RRWeb replayer ignores unknown custom tags unless extended on the web side.
enum CustomDataTag: String, Codable {
    case click = "Click"
    case focus = "Focus"
    case viewport = "Viewport"
    case reload = "Reload"
    case identify = "Identify"
    /// Non-spatial press: remote control, physical keyboard, or software keyboard. Payload: `PressPayload` with `source` discriminator.
    case press = "Press"
    /// Custom analytics event produced by `LDClient.track` (or the manual track path). Payload: stringified JSON `{ "event", "value", "data" }`.
    case track = "Track"
    /// Screen change (or first screen). Payload: the screen name string, mirroring the web SDK's `Navigate` URL payload.
    case navigate = "Navigate"
    /// App entered the foreground (taxonomy `app_foreground`). Payload: stringified JSON `{ "lifecycle_state" }`.
    case appForeground = "Foreground"
    /// App entered the background (taxonomy `app_background`). Payload: stringified JSON `{ "lifecycle_state" }`.
    case appBackground = "Background"
    /// App process launched (taxonomy `app_launch`). Payload: stringified JSON
    /// `{ "launch_type", "version", "build", "previous_version" }` (version fields included when
    /// known; `start.type` stays on the span event only).
    case appLaunch = "Launch"
}
