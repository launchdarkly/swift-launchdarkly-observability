@_exported import UIKit

extension NotificationCenter {
    public func notifications(for name: Notification.Name) -> AsyncStream<Notification.Name> {
        AsyncStream<Notification.Name> { continuation in
            NotificationCenter
                .default
                .addObserver(forName: name,
                             object: nil,
                             queue: nil) { notification in
                    continuation.yield(notification.name)
                }
        }
    }
}
