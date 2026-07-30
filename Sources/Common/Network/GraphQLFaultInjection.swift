import Foundation
import OSLog

#if DEBUG
/// Debug-only helper for exercising Session Replay's recoverable and unrecoverable error paths on a
/// device without a backend change. It fails `initializeSession` and `pushPayload` during even clock
/// minutes and lets them through during odd ones, so a single run alternates between the two states
/// every minute.
///
/// Nothing calls this: it is deliberately left unwired. To use it, add the call at the top of
/// ``GraphQLClient/execute(query:variables:operationName:headers:)`` and remove it again afterwards:
///
/// ```swift
/// #if DEBUG
/// try GraphQLFaultInjection.failIfNeeded(operationName: operationName)
/// #endif
/// ```
enum GraphQLFaultInjection {
    /// The failure to simulate. Change this to exercise a different branch of ``ErrorRecoverability``.
    enum Mode {
        /// A GraphQL error carrying `retryable: false`: unrecoverable, so Session Replay stops taking
        /// screenshots immediately and the refusal is cached for the next launch.
        case nonRetryableGraphQLError
        /// `403`: unrecoverable by status code.
        case unauthorized
        /// `429`: recoverable, so events stay buffered and the call is retried.
        case tooManyRequests
    }

    static let mode = Mode.nonRetryableGraphQLError

    /// Operations covered by the new error handling.
    static let operationNames: Set<String> = ["initializeSession", "PushPayload"]

    private static let log = OSLog(subsystem: "com.launchdarkly.observability", category: "GraphQLFaultInjection")

    static func failIfNeeded(operationName: String?) throws {
        guard let operationName,
              operationNames.contains(operationName),
              isFailingMinute() else {
            return
        }

        os_log("Injecting a simulated %{public}@ failure for %{public}@",
               log: log,
               type: .error,
               String(describing: mode),
               operationName)
        throw simulatedError()
    }

    private static func isFailingMinute(now: Date = Date()) -> Bool {
        Calendar.current.component(.minute, from: now).isMultiple(of: 2)
    }

    private static func simulatedError() -> Error {
        switch mode {
        case .nonRetryableGraphQLError:
            return GraphQLClientError.graphQLErrors([
                GraphQLError(message: "Session replay is not available in this region.",
                             extensions: .init(code: "SESSION_REPLAY_BLOCKED_IN_REGION", retryable: false))
            ])
        case .unauthorized:
            return NetworkError.httpStatus(403, data: nil)
        case .tooManyRequests:
            return NetworkError.httpStatus(429, data: nil)
        }
    }
}
#endif
