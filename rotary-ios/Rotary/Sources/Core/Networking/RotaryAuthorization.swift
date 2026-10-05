import Foundation

typealias RotaryTokenProvider = @MainActor @Sendable (_ forceRefresh: Bool) async throws -> String

@MainActor
func withAuthorizedRetry<T>(
    tokenProvider: RotaryTokenProvider,
    operation: (String) async throws -> T
) async throws -> T {
    do {
        let token = try await tokenProvider(false)
        return try await operation(token)
    } catch {
        guard shouldRetryAuthorizedRequest(after: error) else {
            throw error
        }

        let refreshedToken = try await tokenProvider(true)
        return try await operation(refreshedToken)
    }
}

func shouldRetryAuthorizedRequest(after error: Error) -> Bool {
    switch error {
    case RotaryAPIError.unauthenticated:
        return true
    case let RotaryAPIError.requestFailed(statusCode, _, _, _):
        return statusCode == 401
    default:
        return false
    }
}
