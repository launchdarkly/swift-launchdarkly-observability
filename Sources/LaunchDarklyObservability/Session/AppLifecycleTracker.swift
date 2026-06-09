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
/// Mapping (only these transitions produce a signal):
/// - `willEnterForeground` → `.foreground` with `lifecycleState = foreground`.
/// - `didEnterBackground` → `.background` with `lifecycleState = background`.
final class AppLifecycleTracker: AppLifecycleTracking {
    private let appLifecycleManager: AppLifecycleManaging
    private let yield: (AppLifecycleSignal) -> Void
    private var cancellable: AnyCancellable?

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
        case .willEnterForeground:
            return AppLifecycleSignal(kind: .foreground, lifecycleState: AppLifecycleState.foreground.rawValue)
        case .didEnterBackground:
            return AppLifecycleSignal(kind: .background, lifecycleState: AppLifecycleState.background.rawValue)
        case .didFinishLaunching, .didBecomeActive, .willResignActive, .willTerminate:
            return nil
        }
    }
}
