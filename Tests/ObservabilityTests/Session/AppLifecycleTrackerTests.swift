import Testing
import Combine
@testable import LaunchDarklyObservability

private final class TestLifecycleManager: AppLifecycleManaging {
    private let subject = PassthroughSubject<AppLifeCycleEvent, Never>()

    func publisher() -> AnyPublisher<AppLifeCycleEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    func send(_ event: AppLifeCycleEvent) {
        subject.send(event)
    }
}

struct AppLifecycleTrackerTests {
    private func makeTracker() -> (TestLifecycleManager, AppLifecycleTracker, () -> [AppLifecycleSignal]) {
        let lifecycle = TestLifecycleManager()
        var emitted: [AppLifecycleSignal] = []
        let tracker = AppLifecycleTracker(appLifecycleManager: lifecycle) { signal in
            emitted.append(signal)
        }
        tracker.start()
        return (lifecycle, tracker, { emitted })
    }

    @Test("foreground transition emits .foreground with lifecycleState = foreground")
    func foregroundSignal() {
        let (lifecycle, tracker, emitted) = makeTracker()
        defer { withExtendedLifetime(tracker) {} }

        lifecycle.send(.willEnterForeground)

        let signals = emitted()
        #expect(signals.count == 1)
        #expect(signals[0].kind == .foreground)
        #expect(signals[0].lifecycleState == "foreground")
    }

    @Test("cold-launch didBecomeActive emits the initial .foreground")
    func coldLaunchForegroundSignal() {
        let (lifecycle, tracker, emitted) = makeTracker()
        defer { withExtendedLifetime(tracker) {} }

        // iOS posts no foreground notification on a cold launch, only didBecomeActive.
        lifecycle.send(.didFinishLaunching)
        lifecycle.send(.didBecomeActive)

        let signals = emitted()
        #expect(signals.count == 1)
        #expect(signals[0].kind == .foreground)
        #expect(signals[0].lifecycleState == "foreground")
    }

    @Test("warm return does not double-emit foreground for willEnterForeground + didBecomeActive")
    func warmReturnEmitsSingleForeground() {
        let (lifecycle, tracker, emitted) = makeTracker()
        defer { withExtendedLifetime(tracker) {} }

        lifecycle.send(.willEnterForeground)
        lifecycle.send(.didBecomeActive)

        let signals = emitted()
        #expect(signals.count == 1)
        #expect(signals[0].kind == .foreground)
    }

    @Test("background transition emits .background with lifecycleState = background")
    func backgroundSignal() {
        let (lifecycle, tracker, emitted) = makeTracker()
        defer { withExtendedLifetime(tracker) {} }

        // Background is only meaningful once foregrounded.
        lifecycle.send(.didBecomeActive)
        lifecycle.send(.didEnterBackground)

        let signals = emitted()
        #expect(signals.count == 2)
        #expect(signals[1].kind == .background)
        #expect(signals[1].lifecycleState == "background")
    }

    @Test("a full foreground/background/foreground cycle emits one signal per transition")
    func fullCycle() {
        let (lifecycle, tracker, emitted) = makeTracker()
        defer { withExtendedLifetime(tracker) {} }

        lifecycle.send(.didBecomeActive)     // cold launch foreground
        lifecycle.send(.didEnterBackground)  // background
        lifecycle.send(.willEnterForeground) // warm return foreground
        lifecycle.send(.didBecomeActive)     // deduped

        let kinds = emitted().map(\.kind)
        #expect(kinds == [.foreground, .background, .foreground])
    }

    @Test("transient willResignActive (e.g. Control Center) emits no spurious foreground")
    func transientResignDoesNotDuplicateForeground() {
        let (lifecycle, tracker, emitted) = makeTracker()
        defer { withExtendedLifetime(tracker) {} }

        lifecycle.send(.didBecomeActive)   // foreground
        lifecycle.send(.willResignActive)  // Control Center pulled (no full background)
        lifecycle.send(.didBecomeActive)   // dismissed; already foregrounded

        let signals = emitted()
        #expect(signals.count == 1)
        #expect(signals[0].kind == .foreground)
    }

    @Test("ignored lifecycle events do not emit signals")
    func ignoredEvents() {
        let (lifecycle, tracker, emitted) = makeTracker()
        defer { withExtendedLifetime(tracker) {} }

        lifecycle.send(.didFinishLaunching)
        lifecycle.send(.willResignActive)
        lifecycle.send(.willTerminate)

        #expect(emitted().isEmpty)
    }

    @Test("stop ends signal emission")
    func stopHaltsEmission() {
        let (lifecycle, tracker, emitted) = makeTracker()

        tracker.stop()
        lifecycle.send(.willEnterForeground)

        #expect(emitted().isEmpty)
    }
}
