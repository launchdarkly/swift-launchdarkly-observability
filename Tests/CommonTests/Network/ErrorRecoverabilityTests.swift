import Foundation
import Testing
@testable import Common

private func graphQLErrorBody(retryable: Bool?, code: String = "SESSION_REPLAY_BLOCKED_IN_REGION") -> Data {
    let extensions = retryable.map { "\"extensions\": { \"code\": \"\(code)\", \"retryable\": \($0) }" } ?? "\"extensions\": { \"code\": \"\(code)\" }"
    return Data("""
        {
          "errors": [
            {
              "message": "Session replay is not available in this region.",
              \(extensions)
            }
          ]
        }
        """.utf8)
}

@Suite("ErrorRecoverability")
struct ErrorRecoverabilityTests {

    @Test("4xx statuses are unrecoverable except 400, 408 and 429")
    func clientErrorStatuses() {
        #expect(ErrorRecoverability.isHttpErrorRecoverable(400))
        #expect(ErrorRecoverability.isHttpErrorRecoverable(408))
        #expect(ErrorRecoverability.isHttpErrorRecoverable(429))

        for statusCode in [401, 402, 403, 404, 405, 409, 422, 451, 499] {
            #expect(ErrorRecoverability.isHttpErrorRecoverable(statusCode) == false, "\(statusCode) should be unrecoverable")
        }
    }

    @Test("Server errors and success statuses are recoverable")
    func serverErrorStatuses() {
        for statusCode in [200, 302, 500, 502, 503, 504] {
            #expect(ErrorRecoverability.isHttpErrorRecoverable(statusCode), "\(statusCode) should be recoverable")
        }
    }

    @Test("Network errors are classified by status code")
    func networkErrorsUseStatusCode() {
        #expect(ErrorRecoverability.isErrorRecoverable(NetworkError.httpStatus(403, data: nil)) == false)
        #expect(ErrorRecoverability.isErrorRecoverable(NetworkError.httpStatus(429, data: nil)))
        #expect(ErrorRecoverability.isErrorRecoverable(NetworkError.httpStatus(500, data: nil)))
    }

    @Test("Timeouts and transport failures are recoverable")
    func transportFailuresAreRecoverable() {
        #expect(ErrorRecoverability.isErrorRecoverable(NetworkError.transport(URLError(.timedOut))))
        #expect(ErrorRecoverability.isErrorRecoverable(NetworkError.transport(URLError(.networkConnectionLost))))
        #expect(ErrorRecoverability.isErrorRecoverable(NetworkError.invalidResponse))
    }

    @Test("GraphQL response errors are treated as 4xx")
    func graphQLErrorsAreUnrecoverableByDefault() {
        let errors = [GraphQLError(message: "Session replay is not available in this region.")]
        #expect(ErrorRecoverability.isErrorRecoverable(GraphQLClientError.graphQLErrors(errors)) == false)
    }

    @Test("retryable in GraphQL errors decides the verdict")
    func graphQLRetryableFlagWins() {
        let nonRetryable = [GraphQLError(message: "Blocked", extensions: .init(code: "SESSION_REPLAY_BLOCKED_IN_REGION", retryable: false))]
        #expect(ErrorRecoverability.isErrorRecoverable(GraphQLClientError.graphQLErrors(nonRetryable)) == false)

        let retryable = [GraphQLError(message: "Try later", extensions: .init(code: "BACKEND_BUSY", retryable: true))]
        #expect(ErrorRecoverability.isErrorRecoverable(GraphQLClientError.graphQLErrors(retryable)))

        let mixed = [
            GraphQLError(message: "Try later", extensions: .init(retryable: true)),
            GraphQLError(message: "Blocked", extensions: .init(retryable: false))
        ]
        #expect(ErrorRecoverability.isErrorRecoverable(GraphQLClientError.graphQLErrors(mixed)) == false)
    }

    @Test("retryable in a rejected response body overrides the status code")
    func retryableInResponseBodyOverridesStatus() {
        let blocked = NetworkError.httpStatus(403, data: graphQLErrorBody(retryable: true))
        #expect(ErrorRecoverability.isErrorRecoverable(blocked))

        let throttled = NetworkError.httpStatus(429, data: graphQLErrorBody(retryable: false))
        #expect(ErrorRecoverability.isErrorRecoverable(throttled) == false)

        let withoutFlag = NetworkError.httpStatus(403, data: graphQLErrorBody(retryable: nil))
        #expect(ErrorRecoverability.isErrorRecoverable(withoutFlag) == false)

        let unrelatedBody = NetworkError.httpStatus(403, data: Data("not json".utf8))
        #expect(ErrorRecoverability.isErrorRecoverable(unrelatedBody) == false)
    }

    @Test("Malformed responses and unknown errors stay recoverable")
    func unknownErrorsAreRecoverable() {
        struct SomeError: Error {}

        #expect(ErrorRecoverability.isErrorRecoverable(GraphQLClientError.missingData))
        #expect(ErrorRecoverability.isErrorRecoverable(GraphQLClientError.decoding(SomeError())))
        #expect(ErrorRecoverability.isErrorRecoverable(SomeError()))
    }
}
