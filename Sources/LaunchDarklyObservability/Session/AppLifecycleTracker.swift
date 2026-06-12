import Foundation
import Combine

/// OTel-aligned lifecycle state value carried under `event.lifecycle_state`.
///
/// See the analytics taxonomy (`app_foreground` / `app_background`). iOS exposes
/// more granular states (`active`/`inactive`), but only the foreground/background
/// transitions are surfaced as taxonomy events.
enum AppLifecycleState: String {
    case foreground
    case background
}

protocol AppLifecycleTracking: AutoInstrumentation {}

/// Derives app-lifecycle analytics events (`AppLifecycleSignal`) from UIKit
/// lifecycle notifications, replacing the previous log-based reporting with
/// taxonomy-aligned signals (consumed as both spans and Session Replay breadcrumbs).
///
/// A small foreground/background state machine ensures each genuine visibility
/// transition yields exactly one signal:
/// - `didBecomeActive` / `willEnterForeground` → `.foreground` (only when not already
///   foregrounded). iOS posts **no** foreground notification on a cold launch — it posts
///   `didBecomeActive` instead — so handling `didBecomeActive` is what produces the initial
///   `foreground` on launch (matching Android's `ON_START`). Warm returns post both
///   `willEnterForeground` and `didBecomeActive`; the state guard collapses them to one.
/// - `didEnterBackground` → `.background` (only when currently foregrounded).
/// - `willResignActive` is ignored: it fires for transient interruptions (e.g. Control Center)
///   that are not a full background, so it must not toggle state.
final class AppLifecycleTracker: AppLifecycleTracking {
    private let appLifecycleManager: AppLifecycleManaging
    private let yield: (AppLifecycleSignal) -> Void
    private var cancellable: AnyCancellable?
    private var isForeground = false

    init(appLifecycleManager: AppLifecycleManaging, yield: @escaping (AppLifecycleSignal) -> Void) {
        self.appLifecycleManager = appLifecycleManager
        self.yield = yield
    }

    func start() {
        guard cancellable == nil else { return }

        cancellable = appLifecycleManager
            .publisher()
            .compactMap { [weak self] event in self?.signal(for: event) }
            .sink { [weak self] signal in self?.yield(signal) }
    }

    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }

    private func signal(for event: AppLifeCycleEvent) -> AppLifecycleSignal? {
        switch event {
        case .didBecomeActive, .willEnterForeground:
            guard !isForeground else { return nil }
            isForeground = true
            return AppLifecycleSignal(kind: .foreground, lifecycleState: AppLifecycleState.foreground.rawValue)
        case .didEnterBackground:
            guard isForeground else { return nil }
            isForeground = false
            return AppLifecycleSignal(kind: .background, lifecycleState: AppLifecycleState.background.rawValue)
        case .didFinishLaunching, .willResignActive, .willTerminate:
            return nil
        }
    }
}
