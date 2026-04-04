import Foundation
import Observation
import OSLog

enum SessionPhase {
    case authLoading
    case bootstrapLoading
    case pending(MobileStatusNotice)
    case setupRequired(MobileStatusNotice)
    case blocked(MobileErrorState)
    case ready(MobileBootstrapReadyState)
}

@MainActor
@Observable
final class AppModel {
    private static let cachedReadyStateKey = "rotary.cachedReadyState"

    private let api: RotaryAPIClient
    private var tokenProvider: RotaryTokenProvider?
    private var signOutHandler: (@MainActor () async -> Void)?
    @ObservationIgnored private var bootstrapTask: Task<Void, Never>?
    @ObservationIgnored private var pendingBootstrapForceRefresh = false

    var phase: SessionPhase = .authLoading
    var lastActionMessage: String?
    private(set) var cachedReadyState: MobileBootstrapReadyState?

    init(api: RotaryAPIClient? = nil) {
        self.api = api ?? RotaryAPIClient()
        self.cachedReadyState = Self.loadCachedReadyState()
        if let cachedReadyState {
            phase = .ready(cachedReadyState)
        }
    }

    var apiClient: RotaryAPIClient {
        api
    }

    func resetForSignedOut() async {
        tokenProvider = nil
        bootstrapTask?.cancel()
        bootstrapTask = nil
        pendingBootstrapForceRefresh = false
        phase = .authLoading
        lastActionMessage = nil
        cachedReadyState = nil
        UserDefaults.standard.removeObject(forKey: Self.cachedReadyStateKey)
        await api.resetSessionCaches()
        RotaryLogger.app.log("Resetting to signed-out state")
        RotaryLogger.trace("app reset to signed-out state")
    }

    func configureAuthentication(
        tokenProvider: RotaryTokenProvider?,
        signOutHandler: (@MainActor () async -> Void)? = nil
    ) {
        self.tokenProvider = tokenProvider
        self.signOutHandler = signOutHandler
        RotaryLogger.trace("app configureAuthentication tokenProviderPresent=\(tokenProvider != nil)")
    }

    func bootstrap(forceRefresh: Bool = false) async {
        if let bootstrapTask {
            if forceRefresh {
                pendingBootstrapForceRefresh = true
            }
            await bootstrapTask.value
            return
        }

#if DEBUG
        if (
            ProcessInfo.processInfo.environment["ROTARY_USE_CACHED_BOOTSTRAP_ONLY"] == "1"
                || ProcessInfo.processInfo.arguments.contains("-rotary-use-cached-bootstrap-only")
        ),
           let readyState = cachedReadyState ?? .debugFixture {
            phase = .ready(readyState)
            return
        }
#endif

        if let cachedReadyState {
            phase = .ready(cachedReadyState)
        } else {
            phase = .bootstrapLoading
        }
        let requestedForceRefresh = forceRefresh || pendingBootstrapForceRefresh
        pendingBootstrapForceRefresh = false

        let task = Task { @MainActor [requestedForceRefresh] in
            RotaryLogger.app.log("Bootstrapping Rotary workspace")
            RotaryLogger.trace("bootstrap start forceRefresh=\(requestedForceRefresh)")
            do {
                let payload = try await withAuthorizedRetry(tokenProvider: requireToken) { token in
                    try await api.bootstrap(token: token, forceRefresh: requestedForceRefresh)
                }
                switch payload {
                case let .ready(state):
                    cacheReadyState(state)
                    RotaryLogger.app.log("Bootstrap resolved ready for org \(state.session.orgId, privacy: .public)")
                    RotaryLogger.trace("bootstrap ready org=\(state.session.orgId) lines=\(state.lines.count) agents=\(state.agents.count)")
                    phase = .ready(state)
                case let .setupRequired(state):
                    clearCachedReadyState()
                    RotaryLogger.app.log("Bootstrap resolved setup_required")
                    RotaryLogger.trace("bootstrap setup_required title=\(state.title)")
                    phase = .setupRequired(state)
                case let .pendingAccess(state):
                    clearCachedReadyState()
                    RotaryLogger.app.log("Bootstrap resolved pending_access")
                    RotaryLogger.trace("bootstrap pending_access title=\(state.title)")
                    phase = .pending(state)
                case let .error(state):
                    clearCachedReadyState()
                    RotaryLogger.app.error("Bootstrap resolved error: \(state.message, privacy: .public)")
                    RotaryLogger.trace("bootstrap error message=\(state.message)")
                    phase = .blocked(state)
                }
            } catch is CancellationError {
                RotaryLogger.trace("bootstrap cancelled")
            } catch {
                RotaryLogger.app.error("Bootstrap failed: \(error.localizedDescription, privacy: .public)")
                RotaryLogger.trace("bootstrap failed: \(error.localizedDescription)")
                phase = .blocked(
                    MobileErrorState(
                        status: "error",
                        title: "Unable to load Rotary",
                        message: error.localizedDescription,
                        detail: nil,
                        code: nil,
                        supportEmail: nil,
                        canRetry: true
                    )
                )
            }
        }

        bootstrapTask = task
        await task.value
        bootstrapTask = nil

        if pendingBootstrapForceRefresh {
            await bootstrap(forceRefresh: true)
        }
    }

    func token(forceRefresh: Bool = false) async throws -> String {
        try await requireToken(forceRefresh)
    }

    func createWorkspace(named name: String) async throws {
        try await withAuthorizedRetry(tokenProvider: requireToken) { token in
            try await api.createWorkspace(token: token, businessName: name)
        }
        lastActionMessage = "Workspace created."
        await bootstrap(forceRefresh: true)
    }

    func searchNumbers(areaCode: String, contains: String?) async throws -> [MobileSearchNumber] {
        try await withAuthorizedRetry(tokenProvider: requireToken) { token in
            try await api.searchNumbers(token: token, areaCode: areaCode, contains: contains)
        }
    }

    func provisionOwnerLine(phoneNumber: String) async throws {
        _ = try await withAuthorizedRetry(tokenProvider: requireToken) { token in
            try await api.provisionOwnerLine(token: token, phoneNumber: phoneNumber)
        }
        lastActionMessage = "Main number provisioned."
        await bootstrap(forceRefresh: true)
    }

    func createFirstAgent(
        name: String,
        purpose: String,
        voiceName: String,
        voiceProfileId: String?,
        thinkingMode: String,
        folderId: String?
    ) async throws {
        let agent = try await withAuthorizedRetry(tokenProvider: requireToken) { token in
            try await api.createAgent(
                token: token,
                name: name,
                purpose: purpose,
                voiceName: voiceName,
                voiceProfileId: voiceProfileId,
                thinkingMode: thinkingMode,
                folderId: folderId
            )
        }
        _ = try await withAuthorizedRetry(tokenProvider: requireToken) { token in
            try await api.provisionAgentLine(token: token, agentId: agent.id, folderId: folderId)
        }
        lastActionMessage = "\(agent.name) is ready."
        await bootstrap(forceRefresh: true)
    }

    func listVoicePresets() async throws -> [MobileVoicePreset] {
        let response = try await withAuthorizedRetry(tokenProvider: requireToken) { token in
            try await api.voicePresets(token: token)
        }
        return response.voices
    }

    func createFolder(name: String, description: String?, color: String?) async throws {
        try await withAuthorizedRetry(tokenProvider: requireToken) { token in
            try await api.createFolder(token: token, name: name, description: description, color: color)
        }
        await bootstrap(forceRefresh: true)
    }

    func renameFolder(id: String, name: String) async throws {
        try await withAuthorizedRetry(tokenProvider: requireToken) { token in
            try await api.updateFolder(token: token, folderId: id, name: name)
        }
        await bootstrap(forceRefresh: true)
    }

    func searchContacts(query: String) async throws -> [MobileContactSearchResult] {
        let payload = try await withAuthorizedRetry(tokenProvider: requireToken) { token in
            try await api.searchContacts(token: token, query: query)
        }
        return payload.results
    }

    func createContact(name: String?, phoneNumber: String, email: String? = nil) async throws -> MobileCreatedContact {
        let payload = try await withAuthorizedRetry(tokenProvider: requireToken) { token in
            try await api.createContact(token: token, name: name, phoneNumber: phoneNumber, email: email)
        }
        return payload.contact
    }

    func messageFilters() async throws -> MobileThreadFilterCounts {
        try await withAuthorizedRetry(tokenProvider: requireToken) { token in
            try await api.messageFilters(token: token)
        }
    }

    func updateThreads(contactIds: [String], action: String) async throws {
        _ = try await withAuthorizedRetry(tokenProvider: requireToken) { token in
            try await api.updateThreads(token: token, contactIds: contactIds, action: action)
        }
    }

    func callScreeningSettings() async throws -> MobileCallScreeningSettings {
        try await withAuthorizedRetry(tokenProvider: requireToken) { token in
            try await api.callScreeningSettings(token: token)
        }
    }

    func updateCallScreening(enabled: Bool) async throws -> MobileCallScreeningSettings {
        try await withAuthorizedRetry(tokenProvider: requireToken) { token in
            try await api.updateCallScreeningSettings(token: token, enabled: enabled)
        }
    }

    func sendTraceSnapshot(note: String = "Manual trace snapshot") async throws {
        let token = try await requireToken()
        let phaseSummary: String = switch phase {
        case .authLoading:
            "auth_loading"
        case .bootstrapLoading:
            "bootstrap_loading"
        case .pending:
            "pending"
        case .setupRequired:
            "setup_required"
        case .blocked:
            "blocked"
        case .ready:
            "ready"
        }

        RotaryDiagnosticsReporter.send(
            severity: "info",
            stage: "manual_trace_snapshot",
            message: note,
            context: [
                "phase": phaseSummary,
            ],
            authToken: token
        )
        lastActionMessage = "Trace snapshot sent."
    }

    func signOut() async {
        if let signOutHandler {
            await signOutHandler()
            await resetForSignedOut()
        } else {
            RotaryLogger.auth.error("Sign out requested without an auth handler.")
        }
    }

    private func requireToken(_ forceRefresh: Bool = false) async throws -> String {
        guard let tokenProvider else {
            RotaryLogger.trace("requireToken missing auth token")
            throw RotaryAPIError.unauthenticated
        }
        let token = try await tokenProvider(forceRefresh)
        guard !token.isEmpty else {
            RotaryLogger.trace("requireToken resolved empty auth token")
            throw RotaryAPIError.unauthenticated
        }
        return token
    }

    private static func loadCachedReadyState() -> MobileBootstrapReadyState? {
        guard let data = UserDefaults.standard.data(forKey: cachedReadyStateKey) else {
            return nil
        }
        return try? JSONDecoder.rotary.decode(MobileBootstrapReadyState.self, from: data)
    }

    private func cacheReadyState(_ state: MobileBootstrapReadyState) {
        cachedReadyState = state
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Self.cachedReadyStateKey)
    }

    private func clearCachedReadyState() {
        cachedReadyState = nil
        UserDefaults.standard.removeObject(forKey: Self.cachedReadyStateKey)
    }
}
