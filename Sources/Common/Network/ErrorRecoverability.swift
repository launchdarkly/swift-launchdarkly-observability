import Foundation

/// Classifies request failures as recoverable (retrying may succeed) or unrecoverable (permanent for
/// this launch). Lives outside Session Replay so every caller of the public graph can share one
/// verdict instead of re-deriving it from status codes.
public enum ErrorRecoverability {
    /// Tests whether an HTTP error status represents a condition that might resolve on its own if we
    /// retry.
    /// - Parameter statusCode: the HTTP status
    /// - Returns: `true` if retrying makes sense; `false` if it should be considered a permanent failure
    public static func isHttpErrorRecoverable(_ statusCode: Int) -> Bool {
        guard (400..<500).contains(statusCode) else {
            return true
        }

        switch statusCode {
        case 400, // bad request
             408, // request timeout
             429: // too many requests
            return true
        default:
            return false // all other 4xx errors are unrecoverable
        }
    }

    /// Classifies any error thrown by ``HttpService`` or ``GraphQLClient``. Errors of unknown origin
    /// are treated as recoverable: retrying costs a backed-off request, while a wrong permanent
    /// verdict silently disables a feature for the rest of the launch.
    public static func isErrorRecoverable(_ error: Error) -> Bool {
        switch error {
        case let error as NetworkError:
            return isRecoverable(error)
        case let error as GraphQLClientError:
            return isRecoverable(error)
        default:
            return true
        }
    }

    private static func isRecoverable(_ error: NetworkError) -> Bool {
        switch error {
        case .httpStatus(let statusCode, let data):
            // A rejected request can still carry a GraphQL envelope, and an explicit `retryable`
            // there is more specific than the status code, so it wins.
            if let data, let retryable = retryableFlag(inResponseBody: data) {
                return retryable
            }
            return isHttpErrorRecoverable(statusCode)
        case .transport, .invalidResponse, .invalidRequest:
            // Timeouts, connectivity loss and malformed responses carry no permanent signal.
            return true
        }
    }

    private static func isRecoverable(_ error: GraphQLClientError) -> Bool {
        switch error {
        case .graphQLErrors(let errors):
            // The public graph reports rejections as `200` + `errors`, so these are classified like
            // a generic 4xx: unrecoverable unless the server marks an error retryable.
            return retryableFlag(in: errors) ?? false
        case .missingData, .decoding, .queryFileNotFound, .unreadableQueryFile:
            return true
        }
    }

    /// The server's retry verdict for a set of GraphQL errors, or `nil` when none of them states one.
    private static func retryableFlag(in errors: [GraphQLError]) -> Bool? {
        if errors.contains(where: { $0.extensions?.retryable == false }) {
            return false
        }
        if errors.contains(where: { $0.extensions?.retryable == true }) {
            return true
        }
        return nil
    }

    private static func retryableFlag(inResponseBody data: Data) -> Bool? {
        guard let envelope = try? JSONDecoder().decode(GraphQLErrorEnvelope.self, from: data),
              let errors = envelope.errors else {
            return nil
        }
        return retryableFlag(in: errors)
    }
}
