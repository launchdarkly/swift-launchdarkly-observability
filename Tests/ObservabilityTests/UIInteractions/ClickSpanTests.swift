#if canImport(UIKit)
import Foundation
import Testing
@testable import LaunchDarklyOtel
@testable import LaunchDarklyObservability

/// Tests the `TouchInteraction` -> `ClickEvent` mapping that feeds the click funnel. The funnel then
/// renders the event through `ClickAttributes` (covered by `ClickAttributesTests`) for the span and
/// through Session Replay for the `Click` event, so both pipelines describe the same tap.
struct ClickSpanTests {
    @Test("click event carries the event.* taxonomy fields")
    func clickEventFields() throws {
        let target = TouchTarget(
            className: "UIButton",
            accessibilityIdentifier: "save_profile_btn",
            text: "Save",
            isAccessibilityElement: true,
            rectInWindow: .zero,
            rectOnScreen: .zero,
            rowIndex: nil,
            sceneId: nil
        )
        let interaction = TouchInteraction(
            id: 1,
            kind: .touchUp(CGPoint(x: 12, y: 34)),
            startTimestamp: 1000,
            timestamp: 1001,
            target: target,
            sessionId: "session-1"
        )

        let click = try #require(interaction.clickEvent())

        #expect(click.tag == "UIButton")
        #expect(click.id == "save_profile_btn")
        #expect(click.text == "Save")
        #expect(click.x == 12)
        #expect(click.y == 34)
        // The span covers the whole press, so both ends of the gesture travel with the event.
        #expect(click.startTimestamp == 1000)
        #expect(click.timestamp == 1001)
    }

    @Test("click event omits optional fields when target data is missing")
    func clickEventOmitsOptionalFields() throws {
        let interaction = TouchInteraction(
            id: 2,
            kind: .touchUp(CGPoint(x: 5, y: 6)),
            startTimestamp: 2000,
            timestamp: 2001,
            target: nil,
            sessionId: "session-2"
        )

        let click = try #require(interaction.clickEvent())

        // Required tag falls back to "unknown" when no target is resolved.
        #expect(click.tag == "unknown")
        #expect(click.id == nil)
        #expect(click.text == nil)
        #expect(click.x == 5)
        #expect(click.y == 6)
    }

    @Test("click event includes the screen when a current screen is known")
    func clickEventIncludesScreen() throws {
        let target = TouchTarget(
            className: "UITabBarButton",
            accessibilityIdentifier: "tab.search",
            text: "Search and Explore",
            isAccessibilityElement: true,
            rectInWindow: .zero,
            rectOnScreen: .zero,
            rowIndex: nil,
            sceneId: nil
        )
        let interaction = TouchInteraction(
            id: 4,
            kind: .touchUp(CGPoint(x: 120, y: 818)),
            startTimestamp: 4000,
            timestamp: 4001,
            target: target,
            sessionId: "session-4"
        )

        let click = try #require(
            interaction.clickEvent(screenId: "MyApp.MainTabViewController", screenName: "Home")
        )

        #expect(click.screenId == "MyApp.MainTabViewController")
        #expect(click.screenName == "Home")
        #expect(click.id == "tab.search")
        #expect(click.tag == "UITabBarButton")
    }

    @Test("click event omits the screen when no current screen is known")
    func clickEventOmitsScreen() throws {
        let interaction = TouchInteraction(
            id: 5,
            kind: .touchUp(CGPoint(x: 1, y: 2)),
            startTimestamp: 5000,
            timestamp: 5001,
            target: nil,
            sessionId: "session-5"
        )

        let click = try #require(interaction.clickEvent(screenId: nil, screenName: nil))

        #expect(click.screenId == nil)
        #expect(click.screenName == nil)
    }

    @Test("click event prefers ldId over accessibilityIdentifier for event.id")
    func clickEventPrefersLdId() throws {
        let target = TouchTarget(
            className: "UIButton",
            accessibilityIdentifier: "save_profile_btn",
            ldId: "profile.save",
            text: "Save",
            isAccessibilityElement: true,
            rectInWindow: .zero,
            rectOnScreen: .zero,
            rowIndex: nil,
            sceneId: nil
        )
        let interaction = TouchInteraction(
            id: 6,
            kind: .touchUp(CGPoint(x: 1, y: 2)),
            startTimestamp: 6000,
            timestamp: 6001,
            target: target,
            sessionId: "session-6"
        )

        let click = try #require(interaction.clickEvent())

        #expect(click.id == "profile.save")
    }

    @Test("click event falls back to accessibilityIdentifier when ldId is absent")
    func clickEventFallsBackToAccessibilityIdentifier() throws {
        let target = TouchTarget(
            className: "UIButton",
            accessibilityIdentifier: "save_profile_btn",
            ldId: nil,
            text: "Save",
            isAccessibilityElement: true,
            rectInWindow: .zero,
            rectOnScreen: .zero,
            rowIndex: nil,
            sceneId: nil
        )
        let interaction = TouchInteraction(
            id: 7,
            kind: .touchUp(CGPoint(x: 1, y: 2)),
            startTimestamp: 7000,
            timestamp: 7001,
            target: target,
            sessionId: "session-7"
        )

        let click = try #require(interaction.clickEvent())

        #expect(click.id == "save_profile_btn")
    }

    @Test("a tap the embedder resolves itself is not a click here")
    func embedderOwnedTapIsNotAClick() {
        // Flutter draws its whole UI into one `FlutterView`, so this tap has already been described
        // in Dart and reported through `trackClick`. Reporting it again would duplicate the click as
        // an unhelpful `FlutterView`.
        let target = TouchTarget(
            className: nil,
            accessibilityIdentifier: nil,
            isAccessibilityElement: nil,
            rectInWindow: .zero,
            rectOnScreen: .zero,
            rowIndex: nil,
            sceneId: nil,
            embedderOwned: true
        )
        let interaction = TouchInteraction(
            id: 8,
            kind: .touchUp(CGPoint(x: 1, y: 2)),
            startTimestamp: 8000,
            timestamp: 8001,
            target: target,
            sessionId: "session-8"
        )

        #expect(interaction.clickEvent() == nil)
    }

    @Test("non-tap interactions are not clicks")
    func nonTapInteractionIsNotAClick() {
        let interaction = TouchInteraction(
            id: 3,
            kind: .touchDown(CGPoint(x: 1, y: 2)),
            startTimestamp: 3000,
            timestamp: 3001,
            target: nil,
            sessionId: "session-3"
        )

        #expect(interaction.clickEvent() == nil)
    }
}
#endif
