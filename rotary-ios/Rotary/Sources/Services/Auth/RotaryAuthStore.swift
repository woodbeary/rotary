import Foundation
import Observation
import OSLog
import Security

#if DEBUG
private enum RotaryDebugAuthEnvironment {
    static let email = "ROTARY_DEBUG_EMAIL"
    static let sessionToken = "ROTARY_DEBUG_SESSION_TOKEN"
    static let clientId = "ROTARY_DEBUG_CLIENT_ID"
    static let sessionId = "ROTARY_DEBUG_SESSION_ID"
    static let deviceToken = "ROTARY_DEBUG_DEVICE_TOKEN"
}
#endif

enum RotaryAuthPhase: Equatable {
    case loading
    case signedOut
    case signedIn(RotaryAuthIdentity)
}

@MainActor
@Observable
final class RotaryAuthStore {
    private let service: ClerkNativeAuthService
    private let storage = RotaryAuthStorage()
    @ObservationIgnored private var cachedSessionToken: String?
    @ObservationIgnored private var refreshTask: Task<String, Error>?

    var phase: RotaryAuthPhase = .loading
    var pendingVerification: RotaryPendingVerification?
    var pendingSignInVerification: RotaryPendingSignInVerification?

    init(service: ClerkNativeAuthService? = nil) {
        self.service = service ?? (try! ClerkNativeAuthService())
        pendingVerification = storage.loadPending()
        pendingSignInVerification = storage.loadPendingSignIn()
#if DEBUG
        if let debugContext = Self.debugInjectedContext() {
            cachedSessionToken = debugContext.sessionToken
            phase = .signedIn(
                RotaryAuthIdentity(
                    email: debugContext.email,
                    sessionToken: debugContext.sessionToken
                )
            )
        } else if let context = storage.loadSession() {
            cachedSessionToken = context.sessionToken
            phase = .signedIn(
                RotaryAuthIdentity(
                    email: context.email,
                    sessionToken: context.sessionToken
                )
            )
        } else {
            cachedSessionToken = nil
        }
#else
        if let context = storage.loadSession() {
            cachedSessionToken = context.sessionToken
            phase = .signedIn(
                RotaryAuthIdentity(
                    email: context.email,
                    sessionToken: context.sessionToken
                )
            )
        } else {
            cachedSessionToken = nil
        }
#endif
    }

    var sessionToken: String? {
        guard case .signedIn = phase else {
            return nil
        }
        return cachedSessionToken
    }

    var authSyncKey: String {
        switch phase {
        case .loading:
            return "loading"
        case .signedOut:
            return "signed_out"
        case let .signedIn(identity):
            return "signed_in:\(identity.email)"
        }
    }

    var email: String? {
        switch phase {
        case let .signedIn(identity):
            return identity.email
        case .loading, .signedOut:
            return pendingVerification?.email ?? pendingSignInVerification?.email
        }
    }

    func freshSessionToken(forceRefresh: Bool = false) async throws -> String {
#if DEBUG
        if let debugContext = Self.debugInjectedContext() {
            storage.saveSession(debugContext)
            cachedSessionToken = debugContext.sessionToken
            phase = .signedIn(
                RotaryAuthIdentity(
                    email: debugContext.email,
                    sessionToken: debugContext.sessionToken
                )
            )
            return debugContext.sessionToken
        }
#endif
        if !forceRefresh, let token = sessionToken, !tokenIsExpiringSoon(token) {
            return token
        }

        if let refreshTask {
            return try await refreshTask.value
        }

        guard let context = storage.loadSession() else {
            RotaryLogger.trace("auth refresh requested without stored session")
            cachedSessionToken = nil
            phase = .signedOut
            throw RotaryAPIError.unauthenticated
        }

        let task = Task<String, Error> {
            let refreshed = try await service.restore(context: context)
            await MainActor.run {
                self.storage.saveSession(refreshed)
                self.cachedSessionToken = refreshed.sessionToken
                if case .signedOut = self.phase {
                    self.phase = .signedIn(
                        RotaryAuthIdentity(
                            email: refreshed.email,
                            sessionToken: refreshed.sessionToken
                        )
                    )
                }
                RotaryLogger.trace("auth refresh: token refreshed for \(refreshed.email)")
            }
            return refreshed.sessionToken
        }

        refreshTask = task

        do {
            let token = try await task.value
            refreshTask = nil
            return token
        } catch {
            refreshTask = nil
            RotaryLogger.auth.error("Session token refresh failed: \(error.localizedDescription, privacy: .public)")
            RotaryLogger.trace("auth refresh failed: \(error.localizedDescription)")
            storage.clearSession()
            cachedSessionToken = nil
            phase = .signedOut
            throw error
        }
    }

    func restore() async {
#if DEBUG
        if let debugContext = Self.debugInjectedContext() {
            storage.saveSession(debugContext)
            cachedSessionToken = debugContext.sessionToken
            phase = .signedIn(
                RotaryAuthIdentity(
                    email: debugContext.email,
                    sessionToken: debugContext.sessionToken
                )
            )
            RotaryLogger.trace("auth restore: using injected debug session for \(debugContext.email)")
            return
        }
#endif
        pendingVerification = storage.loadPending()
        pendingSignInVerification = storage.loadPendingSignIn()
        guard let context = storage.loadSession() else {
            RotaryLogger.auth.log("No saved Rotary auth session found")
            RotaryLogger.trace("auth restore: no saved session")
            phase = .signedOut
            return
        }

        if case .signedOut = phase {
            cachedSessionToken = context.sessionToken
            phase = .signedIn(
                RotaryAuthIdentity(
                    email: context.email,
                    sessionToken: context.sessionToken
                )
            )
        }

        do {
            RotaryLogger.auth.log("Restoring Rotary auth session")
            RotaryLogger.trace("auth restore: refreshing existing session for \(context.email)")
            let refreshed = try await service.restore(context: context)
            storage.saveSession(refreshed)
            cachedSessionToken = refreshed.sessionToken
            phase = .signedIn(
                RotaryAuthIdentity(
                    email: refreshed.email,
                    sessionToken: refreshed.sessionToken
                )
            )
            RotaryLogger.trace("auth restore: signed in as \(refreshed.email)")
        } catch {
            RotaryLogger.auth.error("Session restore failed: \(error.localizedDescription, privacy: .public)")
            RotaryLogger.trace("auth restore failed: \(error.localizedDescription)")
            storage.clearSession()
            cachedSessionToken = nil
            phase = .signedOut
        }
    }

    func signIn(email: String, password: String) async throws {
        switch try await service.signIn(email: email, password: password) {
        case let .authenticated(context):
            RotaryLogger.trace("password sign-in complete for \(context.email)")
            storage.saveSession(context)
            cachedSessionToken = context.sessionToken
            storage.clearPending()
            storage.clearPendingSignIn()
            pendingVerification = nil
            pendingSignInVerification = nil
            phase = .signedIn(
                RotaryAuthIdentity(
                    email: context.email,
                    sessionToken: context.sessionToken
                )
            )
        case let .needsVerification(pending):
            RotaryLogger.trace("password sign-in needs verification for \(pending.email) strategy=\(pending.strategy)")
            storage.savePendingSignIn(pending)
            pendingSignInVerification = pending
            phase = .signedOut
        }
    }

    func beginSignUp(email: String, password: String) async throws {
        let pending = try await service.beginSignUp(email: email, password: password)
        storage.savePending(pending)
        storage.clearPendingSignIn()
        pendingVerification = pending
        pendingSignInVerification = nil
        phase = .signedOut
    }

    func verifyEmail(code: String) async throws {
        guard let pending = pendingVerification ?? storage.loadPending() else {
            throw ClerkNativeAuthError.invalidResponse
        }

        let context = try await service.verifySignUp(code: code, pending: pending)
        RotaryLogger.trace("signup verification complete for \(context.email)")
        storage.saveSession(context)
        cachedSessionToken = context.sessionToken
        storage.clearPending()
        storage.clearPendingSignIn()
        pendingVerification = nil
        pendingSignInVerification = nil
        phase = .signedIn(
            RotaryAuthIdentity(
                email: context.email,
                sessionToken: context.sessionToken
            )
        )
    }

    func verifySignIn(code: String) async throws {
        guard let pending = pendingSignInVerification ?? storage.loadPendingSignIn() else {
            throw ClerkNativeAuthError.invalidResponse
        }

        let context = try await service.verifySignIn(code: code, pending: pending)
        RotaryLogger.trace("sign-in verification complete for \(context.email)")
        storage.saveSession(context)
        cachedSessionToken = context.sessionToken
        storage.clearPendingSignIn()
        storage.clearPending()
        pendingVerification = nil
        pendingSignInVerification = nil
        phase = .signedIn(
            RotaryAuthIdentity(
                email: context.email,
                sessionToken: context.sessionToken
            )
        )
    }

    func signOut() async {
        RotaryLogger.trace("sign out requested")
        if let context = storage.loadSession() {
            await service.signOut(context: context)
        }
        storage.clearSession()
        cachedSessionToken = nil
        refreshTask?.cancel()
        refreshTask = nil
        storage.clearPending()
        storage.clearPendingSignIn()
        pendingVerification = nil
        pendingSignInVerification = nil
        phase = .signedOut
    }

    func signIn(ticket: String) async throws {
        RotaryLogger.trace("ticket sign-in requested")
        let context = try await service.signIn(ticket: ticket)
        RotaryLogger.trace("ticket sign-in complete for \(context.email)")
        storage.saveSession(context)
        cachedSessionToken = context.sessionToken
        storage.clearPending()
        storage.clearPendingSignIn()
        pendingVerification = nil
        pendingSignInVerification = nil
        phase = .signedIn(
            RotaryAuthIdentity(
                email: context.email,
                sessionToken: context.sessionToken
            )
        )
    }

    private func tokenIsExpiringSoon(_ token: String) -> Bool {
        guard let payload = decodeJwtPayload(token),
              let exp = payload["exp"] as? TimeInterval else {
            return false
        }

        let expiryDate = Date(timeIntervalSince1970: exp)
        return expiryDate.timeIntervalSinceNow < 300
    }

    private func decodeJwtPayload(_ token: String) -> [String: Any]? {
        let components = token.split(separator: ".")
        guard components.count > 1 else { return nil }

        var payload = String(components[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = payload.count % 4
        if remainder != 0 {
            payload += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return object
    }

#if DEBUG
    private static func debugInjectedContext() -> RotaryAuthContext? {
        let environment = ProcessInfo.processInfo.environment
        guard let email = environment[RotaryDebugAuthEnvironment.email]?.trimmingCharacters(in: .whitespacesAndNewlines),
              let sessionToken = environment[RotaryDebugAuthEnvironment.sessionToken]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !email.isEmpty,
              !sessionToken.isEmpty else {
            return nil
        }

        let clientId = environment[RotaryDebugAuthEnvironment.clientId]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sessionId = environment[RotaryDebugAuthEnvironment.sessionId]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let deviceToken = environment[RotaryDebugAuthEnvironment.deviceToken]?.trimmingCharacters(in: .whitespacesAndNewlines)

        return RotaryAuthContext(
            email: email,
            clientId: (clientId?.isEmpty == false ? clientId! : "debug-client"),
            sessionId: (sessionId?.isEmpty == false ? sessionId! : "debug-session"),
            deviceToken: (deviceToken?.isEmpty == false ? deviceToken! : "debug-device"),
            sessionToken: sessionToken
        )
    }
#endif
}

private final class RotaryAuthStorage {
    private let keychain = RotaryKeychainStore(service: "com.theinterpretingapp.rotary.auth")
    private let sessionAccount = "session"
    private let pendingAccount = "pending-verification"
    private let defaults = UserDefaults.standard

    func saveSession(_ context: RotaryAuthContext) {
        if let data = try? JSONEncoder().encode(context) {
            keychain.set(data, account: sessionAccount)
        }
    }

    func loadSession() -> RotaryAuthContext? {
        guard let data = keychain.data(account: sessionAccount) else {
            return nil
        }
        return try? JSONDecoder().decode(RotaryAuthContext.self, from: data)
    }

    func clearSession() {
        keychain.delete(account: sessionAccount)
    }

    func savePending(_ pending: RotaryPendingVerification) {
        if let data = try? JSONEncoder().encode(pending) {
            defaults.set(data, forKey: pendingAccount)
        }
    }

    func loadPending() -> RotaryPendingVerification? {
        guard let data = defaults.data(forKey: pendingAccount) else {
            return nil
        }
        return try? JSONDecoder().decode(RotaryPendingVerification.self, from: data)
    }

    func clearPending() {
        defaults.removeObject(forKey: pendingAccount)
    }

    func savePendingSignIn(_ pending: RotaryPendingSignInVerification) {
        if let data = try? JSONEncoder().encode(pending) {
            defaults.set(data, forKey: "pending-sign-in")
        }
    }

    func loadPendingSignIn() -> RotaryPendingSignInVerification? {
        guard let data = defaults.data(forKey: "pending-sign-in") else {
            return nil
        }
        return try? JSONDecoder().decode(RotaryPendingSignInVerification.self, from: data)
    }

    func clearPendingSignIn() {
        defaults.removeObject(forKey: "pending-sign-in")
    }
}

private struct RotaryKeychainStore {
    let service: String

    func set(_ data: Data, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            attributes.forEach { addQuery[$0.key] = $0.value }
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    func data(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
