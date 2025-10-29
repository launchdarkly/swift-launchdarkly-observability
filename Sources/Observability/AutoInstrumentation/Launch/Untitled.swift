#if canImport(UIKit)
import Foundation
import UIKit

/// A utility to measure the time between app launch and the first frame drawn.
/// Works on iOS/tvOS 13 and later, compatible with Swift Packages.
public final class LaunchTimeTracker {
    
    /// Shared singleton instance.
    public static let shared = LaunchTimeTracker()
    
    /// Timestamp when the app started launching.
    private var launchStartTime: TimeInterval?
    
    /// Timestamp when the first screen has been drawn.
    private var firstFrameTime: TimeInterval?
    
    /// Computed time interval from app start to first screen draw.
    public private(set) var launchDuration: TimeInterval?
    
    /// Indicates if metrics have already been recorded.
    public private(set) var hasRecorded: Bool = false
    
    /// Internal queue to ensure thread-safety.
    private let syncQueue = DispatchQueue(label: "LaunchTimeTracker.sync.queue")
    
    private init() {}
    
    // MARK: - Public API
    
    /// Call this very early — typically in `main.swift` or at the top of `AppDelegate.init()`
    public func markLaunchStart() {
        syncQueue.sync {
            guard launchStartTime == nil else { return }
            launchStartTime = ProcessInfo.processInfo.systemUptime
        }
    }
    
    /// Call this once the first frame of the UI has been rendered.
    /// For example, from `UIViewController.viewDidAppear(_:)` in your root view controller.
    public func markFirstFrameDrawn() {
        syncQueue.sync {
            guard !hasRecorded else { return }
            
            firstFrameTime = ProcessInfo.processInfo.systemUptime
            
            if let start = launchStartTime, let end = firstFrameTime {
                launchDuration = end - start
                hasRecorded = true
                notifyObservers()
            }
        }
    }
    
    /// Returns whether the launch is cold or warm.
    /// - A cold launch means the app process was newly created.
    /// - A warm launch means the app was already in memory (e.g., after backgrounding).
    public var launchType: LaunchType {
        if isiOSAppOnMac {
            return .unknown
        }
        return isColdLaunch ? .cold : .warm
    }

    private var isiOSAppOnMac: Bool {
        if #available(iOS 14.0, tvOS 14.0, *) {
            return ProcessInfo.processInfo.isiOSAppOnMac
        } else {
            return false
        }
    }
    
    /// Adds an observer for when the first frame time is recorded.
    public func addObserver(_ observer: @escaping (TimeInterval, LaunchType) -> Void) {
        NotificationCenter.default.addObserver(forName: .launchTimeRecorded,
                                               object: nil,
                                               queue: .main) { [weak self] _ in
            guard let self, let duration = self.launchDuration else { return }
            observer(duration, self.launchType)
        }
    }
    
    // MARK: - Helpers
    
    private func notifyObservers() {
        NotificationCenter.default.post(name: .launchTimeRecorded, object: nil)
    }
    
    private var isColdLaunch: Bool {
        // Rough heuristic: cold launch if no existing scene sessions.
        return UIApplication.shared.connectedScenes.isEmpty
//        if let connectedScenes = UIApplication.shared.connectedScenes as? Set<UIScene>,
//           connectedScenes.isEmpty {
//            return true
//        }
        
//        return false
    }
    
    // MARK: - Types
    
    public enum LaunchType: String {
        case cold
        case warm
        case unknown
    }
}

// MARK: - Notification Name
public extension Notification.Name {
    static let launchTimeRecorded = Notification.Name("LaunchTimeTracker.launchTimeRecorded")
}
#endif
