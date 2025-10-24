import Foundation

extension Task where Success == Never, Failure == Never {
    
    /// Suspends the current task until the given deadline within a tolerance.
    ///
    /// If the task is canceled before the time ends, this function throws
    /// `CancellationError`.
    ///
    /// This function doesn't block the underlying thread.
    ///
    ///       try await Task.sleep(seconds: 3.0)
    ///
    public static func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * Double(NSEC_PER_SEC)))
    }
}
