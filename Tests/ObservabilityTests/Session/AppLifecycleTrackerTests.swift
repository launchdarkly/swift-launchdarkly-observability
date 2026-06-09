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

    @Test("background transition emits .background with lifecycleState = background")
    func backgroundSignal() {
        let (lifecycle, tracker, emitted) = makeTracker()
        defer { withExtendedLifetime(tracker) {} }

        lifecycle.send(.didEnterBackground)

        let signals = emitted()
        #expect(signals.count == 1)
        #expect(signals[0].kind == .background)
        #expect(signals[0].lifecycleState == "background")
    }

    @Test("ignored lifecycle events do not emit signals")
    func ignoredEvents() {
        let (lifecycle, tracker, emitted) = makeTracker()
        defer { withExtendedLifetime(tracker) {} }

        lifecycle.send(.didFinishLaunching)
        lifecycle.send(.didBecomeActive)
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
