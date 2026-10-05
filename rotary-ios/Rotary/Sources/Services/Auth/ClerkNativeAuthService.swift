import Foundation
import OSLog

enum ClerkNativeAuthError: LocalizedError {
    case invalidFrontendURL
    case invalidResponse
    case missingDeviceToken
    case missingClient
    case missingSession
    case signedOut
    case unsupportedStatus(String)
    case api(message: String, traceId: String?)

    var errorDescription: String? {
        switch self {
        case .invalidFrontendURL:
            return "Rotary is missing a valid Clerk frontend URL."
        case .invalidResponse:
            return "Clerk returned an unexpected response."
        case .missingDeviceToken:
            return "Clerk did not return a device token."
        case .missingClient:
            return "Clerk did not return a client session."
        case .missingSession:
            return "Clerk did not create an active session."
        case .signedOut:
            return "Your session expired. Please sign in again."
        case let .unsupportedStatus(status):
            return "Rotary does not support this Clerk auth state yet: \(status)."
        case let .api(message, traceId):
            if let traceId, !traceId.isEmpty {
                return "\(message) (trace \(traceId))"
            }
            return message
        }
    }
}

struct RotaryAuthContext: Codable, Sendable, Equatable {
    let email: String
    let clientId: String
    let sessionId: String
    let deviceToken: String
    let sessionToken: String
}

struct RotaryPendingVerification: Codable, Sendable, Equatable {
    let email: String
    let signUpId: String
    let clientId: String
    let deviceToken: String
}

struct RotaryPendingSignInVerification: Codable, Sendable, Equatable {
    let email: String
    let signInId: String
    let clientId: String
    let deviceToken: String
    let strategy: String
}

struct RotaryAuthIdentity: Sendable, Equatable {
    let email: String
    let sessionToken: String
}

enum RotarySignInResult: Sendable, Equatable {
    case authenticated(RotaryAuthContext)
    case needsVerification(RotaryPendingSignInVerification)
}

final class ClerkNativeAuthService: @unchecked Sendable {
    private static let apiVersion = "2025-11-10"

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    private func isUsableSessionStatus(_ status: String) -> Bool {
        status == "active" || status == "pending"
    }

    init(config: AppConfig? = nil, session: URLSession = .shared) throws {
        let resolvedConfig = config ?? .shared
        guard let baseURL = URL(string: "https://\(resolvedConfig.clerkFrontendAPI)") else {
            throw ClerkNativeAuthError.invalidFrontendURL
        }

        self.baseURL = baseURL
        self.session = session
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    func restore(context: RotaryAuthContext) async throws -> RotaryAuthContext {
        let transport = ClerkTransportContext(
            clientId: context.clientId,
            deviceToken: context.deviceToken
        )

        let result = try await send(
            path: "/v1/client",
            method: "GET",
            transport: transport
        )
        let clientEnvelope = try decoder.decode(ClerkClientEnvelope.self, from: result.data)
        let client = clientEnvelope.response

        let sessionId: String
        if client.sessions.contains(where: { $0.id == context.sessionId && isUsableSessionStatus($0.status) }) {
            sessionId = context.sessionId
        } else if let lastActive = client.lastActiveSessionId,
                  client.sessions.contains(where: { $0.id == lastActive && isUsableSessionStatus($0.status) }) {
            sessionId = lastActive
        } else if let usable = client.sessions.first(where: { isUsableSessionStatus($0.status) }) {
            sessionId = usable.id
        } else {
            throw ClerkNativeAuthError.signedOut
        }

        let token = try await createSessionToken(
            sessionId: sessionId,
            clientId: client.id,
            deviceToken: result.deviceToken ?? context.deviceToken
        )

        return RotaryAuthContext(
            email: context.email,
            clientId: client.id,
            sessionId: sessionId,
            deviceToken: result.deviceToken ?? context.deviceToken,
            sessionToken: token
        )
    }

    func signIn(email: String, password: String) async throws -> RotarySignInResult {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        RotaryLogger.auth.log("Starting sign-in for \(normalizedEmail, privacy: .public)")
        RotaryLogger.trace("Clerk password sign-in start for \(normalizedEmail)")
        let result = try await send(
            path: "/v1/client/sign_ins",
            method: "POST",
            body: [
                "identifier": normalizedEmail,
                "password": password,
                "strategy": "password",
                "locale": Locale.current.identifier,
            ]
        )

        let envelope = try decoder.decode(ClerkAttemptEnvelope<ClerkSignInAttempt>.self, from: result.data)
        let attempt = try envelope.requireResponse()
        let client = try envelope.requireClient()
        guard let deviceToken = result.deviceToken else {
            throw ClerkNativeAuthError.missingDeviceToken
        }

        RotaryLogger.auth.log("Sign-in status \(attempt.status, privacy: .public)")
        RotaryLogger.trace("Clerk password sign-in status=\(attempt.status)")

        switch attempt.status {
        case "complete":
            guard let sessionId = attempt.createdSessionId else {
                throw ClerkNativeAuthError.missingSession
            }

            let token = try await createSessionToken(
                sessionId: sessionId,
                clientId: client.id,
                deviceToken: deviceToken
            )

            return .authenticated(
                RotaryAuthContext(
                    email: normalizedEmail,
                    clientId: client.id,
                    sessionId: sessionId,
                    deviceToken: deviceToken,
                    sessionToken: token
                )
            )
        case "needs_client_trust", "needs_second_factor":
            let strategy = preferredSecondFactor(from: attempt)
            try await prepareSecondFactor(
                signInId: attempt.id,
                strategy: strategy,
                clientId: client.id,
                deviceToken: deviceToken
            )

            return .needsVerification(
                RotaryPendingSignInVerification(
                    email: normalizedEmail,
                    signInId: attempt.id,
                    clientId: client.id,
                    deviceToken: deviceToken,
                    strategy: strategy
                )
            )
        default:
            throw ClerkNativeAuthError.unsupportedStatus(attempt.status)
        }
    }

    func beginSignUp(email: String, password: String) async throws -> RotaryPendingVerification {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let createResult = try await send(
            path: "/v1/client/sign_ups",
            method: "POST",
            body: [
                "email_address": normalizedEmail,
                "password": password,
                "locale": Locale.current.identifier,
            ]
        )

        let createEnvelope = try decoder.decode(ClerkAttemptEnvelope<ClerkSignUpAttempt>.self, from: createResult.data)
        let signUp = try createEnvelope.requireResponse()
        let client = try createEnvelope.requireClient()
        guard let deviceToken = createResult.deviceToken else {
            throw ClerkNativeAuthError.missingDeviceToken
        }

        _ = try await send(
            path: "/v1/client/sign_ups/\(signUp.id)/prepare_verification",
            method: "POST",
            body: ["strategy": "email_code"],
            transport: ClerkTransportContext(clientId: client.id, deviceToken: deviceToken)
        )

        return RotaryPendingVerification(
            email: normalizedEmail,
            signUpId: signUp.id,
            clientId: client.id,
            deviceToken: deviceToken
        )
    }

    func verifySignUp(code: String, pending: RotaryPendingVerification) async throws -> RotaryAuthContext {
        let result = try await send(
            path: "/v1/client/sign_ups/\(pending.signUpId)/attempt_verification",
            method: "POST",
            body: [
                "strategy": "email_code",
                "code": code.trimmingCharacters(in: .whitespacesAndNewlines),
            ],
            transport: ClerkTransportContext(clientId: pending.clientId, deviceToken: pending.deviceToken)
        )

        let envelope = try decoder.decode(ClerkAttemptEnvelope<ClerkSignUpAttempt>.self, from: result.data)
        let signUp = try envelope.requireResponse()
        guard signUp.status == "complete" else {
            throw ClerkNativeAuthError.unsupportedStatus(signUp.status)
        }

        guard let sessionId = signUp.createdSessionId else {
            throw ClerkNativeAuthError.missingSession
        }

        let client = try envelope.requireClient()
        let deviceToken = result.deviceToken ?? pending.deviceToken

        let token = try await createSessionToken(
            sessionId: sessionId,
            clientId: client.id,
            deviceToken: deviceToken
        )

        return RotaryAuthContext(
            email: pending.email,
            clientId: client.id,
            sessionId: sessionId,
            deviceToken: deviceToken,
            sessionToken: token
        )
    }

    func verifySignIn(code: String, pending: RotaryPendingSignInVerification) async throws -> RotaryAuthContext {
        RotaryLogger.auth.log("Verifying sign-in challenge for \(pending.email, privacy: .public)")
        RotaryLogger.trace("Clerk second-factor verify start for \(pending.email)")
        let result = try await send(
            path: "/v1/client/sign_ins/\(pending.signInId)/attempt_second_factor",
            method: "POST",
            body: [
                "strategy": pending.strategy,
                "code": code.trimmingCharacters(in: .whitespacesAndNewlines),
            ],
            transport: ClerkTransportContext(clientId: pending.clientId, deviceToken: pending.deviceToken)
        )

        let envelope = try decoder.decode(ClerkAttemptEnvelope<ClerkSignInAttempt>.self, from: result.data)
        let attempt = try envelope.requireResponse()
        guard attempt.status == "complete" else {
            throw ClerkNativeAuthError.unsupportedStatus(attempt.status)
        }

        guard let sessionId = attempt.createdSessionId else {
            throw ClerkNativeAuthError.missingSession
        }

        let client = try envelope.requireClient()
        let deviceToken = result.deviceToken ?? pending.deviceToken
        let token = try await createSessionToken(
            sessionId: sessionId,
            clientId: client.id,
            deviceToken: deviceToken
        )

        return RotaryAuthContext(
            email: pending.email,
            clientId: client.id,
            sessionId: sessionId,
            deviceToken: deviceToken,
            sessionToken: token
        )
    }

    func signIn(ticket: String) async throws -> RotaryAuthContext {
        RotaryLogger.auth.log("Starting ticket-based sign-in")
        RotaryLogger.trace("Clerk ticket sign-in start")
        let result = try await send(
            path: "/v1/client/sign_ins",
            method: "POST",
            body: [
                "strategy": "ticket",
                "ticket": ticket.trimmingCharacters(in: .whitespacesAndNewlines),
            ]
        )

        let envelope = try decoder.decode(ClerkAttemptEnvelope<ClerkSignInAttempt>.self, from: result.data)
        let attempt = try envelope.requireResponse()
        RotaryLogger.trace("Clerk ticket sign-in status=\(attempt.status)")
        guard attempt.status == "complete" else {
            throw ClerkNativeAuthError.unsupportedStatus(attempt.status)
        }

        guard let sessionId = attempt.createdSessionId else {
            throw ClerkNativeAuthError.missingSession
        }

        let client = try envelope.requireClient()
        guard let deviceToken = result.deviceToken else {
            throw ClerkNativeAuthError.missingDeviceToken
        }

        let sessionToken = try await createSessionToken(
            sessionId: sessionId,
            clientId: client.id,
            deviceToken: deviceToken
        )
        RotaryLogger.trace("Clerk ticket sign-in session token created")

        let email = attempt.identifier ?? "support@rotary.app"
        return RotaryAuthContext(
            email: email,
            clientId: client.id,
            sessionId: sessionId,
            deviceToken: deviceToken,
            sessionToken: sessionToken
        )
    }

    func signOut(context: RotaryAuthContext) async {
        _ = try? await send(
            path: "/v1/client/sessions",
            method: "DELETE",
            transport: ClerkTransportContext(clientId: context.clientId, deviceToken: context.deviceToken)
        )
    }

    private func createSessionToken(
        sessionId: String,
        clientId: String,
        deviceToken: String
    ) async throws -> String {
        let result = try await send(
            path: "/v1/client/sessions/\(sessionId)/tokens",
            method: "POST",
            transport: ClerkTransportContext(clientId: clientId, deviceToken: deviceToken)
        )

        let tokenPayload = try decoder.decode(ClerkTokenResource.self, from: result.data)
        guard let jwt = tokenPayload.jwt, !jwt.isEmpty else {
            throw ClerkNativeAuthError.missingSession
        }
        return jwt
    }

    private func preferredSecondFactor(from attempt: ClerkSignInAttempt) -> String {
        let preferred = attempt.supportedSecondFactors?
            .compactMap(\.strategy)
            .first(where: { $0 == "email_code" || $0 == "phone_code" })

        if let preferred {
            return preferred
        }

        return "email_code"
    }

    private func prepareSecondFactor(
        signInId: String,
        strategy: String,
        clientId: String,
        deviceToken: String
    ) async throws {
        RotaryLogger.auth.log("Preparing second factor \(strategy, privacy: .public)")
        _ = try await send(
            path: "/v1/client/sign_ins/\(signInId)/prepare_second_factor",
            method: "POST",
            body: ["strategy": strategy],
            transport: ClerkTransportContext(clientId: clientId, deviceToken: deviceToken)
        )
    }

    private func send(
        path: String,
        method: String,
        body: [String: String?]? = nil,
        transport: ClerkTransportContext? = nil
    ) async throws -> ClerkTransportResult {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), resolvingAgainstBaseURL: false) else {
            throw ClerkNativeAuthError.invalidResponse
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "_is_native", value: "true"))
        components.queryItems = queryItems

        guard let url = components.url else {
            throw ClerkNativeAuthError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "clerk-api-version")
        request.setValue("1", forHTTPHeaderField: "x-mobile")

        if let transport {
            request.setValue(transport.deviceToken, forHTTPHeaderField: "Authorization")
            request.setValue(transport.clientId, forHTTPHeaderField: "x-clerk-client-id")
        }

        if let body {
            let encodedBody = body
                .compactMap { key, value -> String? in
                    guard let value else { return nil }
                    let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                    let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                    return "\(encodedKey)=\(encodedValue)"
                }
                .joined(separator: "&")
            request.httpBody = encodedBody.data(using: .utf8)
        }

        RotaryLogger.auth.log("Clerk request \(method, privacy: .public) \(path, privacy: .public)")
        RotaryLogger.trace("Clerk request \(method) \(path)")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClerkNativeAuthError.invalidResponse
        }

        RotaryLogger.auth.log("Clerk response \(httpResponse.statusCode, privacy: .public) for \(path, privacy: .public)")
        RotaryLogger.trace("Clerk response \(httpResponse.statusCode) for \(path)")

        if !(200 ... 299).contains(httpResponse.statusCode) {
            let errorEnvelope = try? decoder.decode(ClerkErrorEnvelope.self, from: data)
            let problem = errorEnvelope?.errors.first
            let message = problem?.longMessage ?? problem?.message ?? "Authentication failed."
            let code = problem?.code ?? ""
            if code == "signed_out" {
                throw ClerkNativeAuthError.signedOut
            }
            throw ClerkNativeAuthError.api(message: message, traceId: errorEnvelope?.clerkTraceId)
        }

        return ClerkTransportResult(
            data: data,
            deviceToken: httpResponse.value(forHTTPHeaderField: "Authorization")
        )
    }
}

private struct ClerkTransportContext {
    let clientId: String
    let deviceToken: String
}

private struct ClerkTransportResult {
    let data: Data
    let deviceToken: String?
}

private struct ClerkTokenResource: Decodable {
    let jwt: String?
}

private struct ClerkErrorEnvelope: Decodable {
    let errors: [ClerkProblem]
    let clerkTraceId: String?
}

private struct ClerkProblem: Decodable {
    let code: String?
    let message: String?
    let longMessage: String?
}

private struct ClerkClientEnvelope: Decodable {
    let response: ClerkClient
}

private struct ClerkAttemptEnvelope<Response: Decodable>: Decodable {
    let response: Response?
    let client: ClerkClient?
    let meta: ClerkMeta?

    func requireResponse() throws -> Response {
        guard let response else {
            throw ClerkNativeAuthError.invalidResponse
        }
        return response
    }

    func requireClient() throws -> ClerkClient {
        if let client {
            return client
        }
        if let metaClient = meta?.client {
            return metaClient
        }
        throw ClerkNativeAuthError.missingClient
    }
}

private struct ClerkMeta: Decodable {
    let client: ClerkClient?
}

private struct ClerkClient: Decodable {
    let id: String
    let sessions: [ClerkSession]
    let lastActiveSessionId: String?
}

private struct ClerkSession: Decodable {
    let id: String
    let status: String
}

private struct ClerkSignInAttempt: Decodable {
    let id: String
    let status: String
    let createdSessionId: String?
    let identifier: String?
    let supportedSecondFactors: [ClerkVerificationFactor]?
}

private struct ClerkSignUpAttempt: Decodable {
    let id: String
    let status: String
    let createdSessionId: String?
}

private struct ClerkVerificationFactor: Decodable {
    let strategy: String?
    let safeIdentifier: String?
}
