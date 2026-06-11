import Foundation
import OpenTelemetryApi

/// A single screen appearance, mapped to the taxonomy `screen_view` event.
///
/// Only `name` is required by the taxonomy; the other fields are optional and
/// emitted under the `event.*` namespace when present.
struct ScreenView: Equatable {
    /// Human-readable screen name, e.g. `Profile`. Maps to `event.name`.
    let name: String
    /// View controller class, e.g. `ProfileViewController`. Maps to `event.screen_class`.
    let screenClass: String?
    /// Stable, module-qualified identifier, e.g. `MyApp.ProfileViewController`. Maps to `event.screen_id`.
    let screenId: String?
    /// Screen group, e.g. `Onboarding`. Maps to `event.category`.
    let category: String?
    /// Optional caller-supplied attributes attached to the `screen_view` span,
    /// applied at lower precedence than the reserved `event.*` fields so they can
    /// never clobber the taxonomy. Empty for automatically captured screens.
    let attributes: [String: AttributeValue]
    /// Capture time.
    let timestamp: TimeInterval

    init(name: String,
         screenClass: String? = nil,
         screenId: String? = nil,
         category: String? = nil,
         attributes: [String: AttributeValue] = [:],
         timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.name = name
        self.screenClass = screenClass
        self.screenId = screenId
        self.category = category
        self.attributes = attributes
        self.timestamp = timestamp
    }
}
