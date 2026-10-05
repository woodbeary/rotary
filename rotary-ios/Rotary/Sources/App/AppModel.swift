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
    private static let firstRunOnboardingStateKey = "rotary.firstRunOnboardingState"
    static let firstRunOnboardingVersion = 1

    private let api: RotaryAPIClient
    let mutationDispatcher: RotaryMutationDispatcher
    let inferenceModeStore: InferenceModeStore
    let connectivityMonitor: ConnectivityMonitor
    @ObservationIgnored private let contactsImportCoordinator = DeviceContactsImportCoordinator()
    private var tokenProvider: RotaryTokenProvider?
    private var signOutHandler: (@MainActor () async -> Void)?
    @ObservationIgnored private var bootstrapTask: Task<Void, Never>?
    @ObservationIgnored private var pendingBootstrapForceRefresh = false
    @ObservationIgnored private var voicePresetTask: Task<[MobileVoicePreset], Error>?
    @ObservationIgnored private var cachedVoicePresets: [MobileVoicePreset] = []

    var phase: SessionPhase = .authLoading
    var lastActionMessage: String?
    private(set) var cachedReadyState: MobileBootstrapReadyState?
    private(set) var firstRunOnboardingState: FirstRunOnboardingState

    init(
        api: RotaryAPIClient? = nil,
        mutationDispatcher: RotaryMutationDispatcher? = nil,
        inferenceModeStore: InferenceModeStore = .shared,
        connectivityMonitor: ConnectivityMonitor = .shared
    ) {
        let resolvedAPI = api ?? RotaryAPIClient()
        self.api = resolvedAPI
        self.mutationDispatcher = mutationDispatcher ?? RotaryMutationDispatcher(api: resolvedAPI)
        self.inferenceModeStore = inferenceModeStore
        self.connectivityMonitor = connectivityMonitor
        self.cachedReadyState = Self.loadCachedReadyState()
        self.firstRunOnboardingState = Self.loadFirstRunOnboardingState()
        if let cachedReadyState {
            phase = .ready(cachedReadyState)
        }
    }

    var apiClient: RotaryAPIClient {
        api
    }

    var cachedVoicePresetsSnapshot: [MobileVoicePreset] {
        cachedVoicePresets
    }

    var shouldShowFirstRunOnboarding: Bool {
#if DEBUG
        if ProcessInfo.processInfo.environment["ROTARY_DEBUG_SKIP_FIRST_RUN_ONBOARDING"] == "1" {
            return false
        }
#endif
        guard case let .ready(readyState) = phase else {
            return false
        }
        return !firstRunOnboardingState.isCompleted(
            for: readyState.session.orgId,
            version: Self.firstRunOnboardingVersion
        )
    }

    func resetForSignedOut() async {
        tokenProvider = nil
        mutationDispatcher.configureTokenProvider(nil)
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
        mutationDispatcher.configureTokenProvider(tokenProvider)
        self.signOutHandler = signOutHandler
        RotaryLogger.trace("app configureAuthentication tokenProviderPresent=\(tokenProvider != nil)")
        if tokenProvider != nil {
            Task { await mutationDispatcher.flushPendingMutations() }
        }
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
                    Task { await prewarmVoicePresets() }
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
        let result = try await mutationDispatcher.createWorkspace(name: name)
        switch result {
        case .executed:
            lastActionMessage = "Workspace created."
            await bootstrap(forceRefresh: true)
        case .queued:
            lastActionMessage = "Workspace saved offline. Rotary will sync it when you're back online."
        }
    }

    func searchNumbers(areaCode: String, contains: String?) async throws -> [MobileSearchNumber] {
        try await withAuthorizedRetry(tokenProvider: requireToken) { token in
            try await api.searchNumbers(token: token, areaCode: areaCode, contains: contains)
        }
    }

    func provisionOwnerLine(phoneNumber: String) async throws {
        let tempID = "temp-line:\(UUID().uuidString)"
        let result = try await mutationDispatcher.provisionOwnerLine(tempID: tempID, phoneNumber: phoneNumber)
        switch result {
        case .executed:
            lastActionMessage = "Main number provisioned."
            await bootstrap(forceRefresh: true)
        case .queued:
            lastActionMessage = "Number provisioning is queued offline and will sync automatically."
        }
    }

    @discardableResult
    func createFirstAgent(
        name: String,
        purpose: String,
        voiceName: String,
        voiceProfileId: String?,
        thinkingMode: String,
        folderId: String?
    ) async throws -> MobileAgent? {
        let tempAgentID = "temp-agent:\(UUID().uuidString)"
        let creation = try await mutationDispatcher.createAgent(
            tempID: tempAgentID,
            name: name,
            purpose: purpose,
            voiceName: voiceName,
            voiceProfileId: voiceProfileId,
            thinkingMode: thinkingMode,
            folderId: folderId
        )

        let provisionTargetID: String
        switch creation {
        case .executed(let agent):
            provisionTargetID = agent.id
        case .queued:
            provisionTargetID = tempAgentID
        }

        let provision = try await mutationDispatcher.provisionAgentLine(
            agentId: provisionTargetID,
            folderId: folderId
        )

        let createdAgent: MobileAgent?
        if case let .executed(agent) = creation {
            createdAgent = agent
        } else {
            createdAgent = nil
        }

        switch (creation, provision) {
        case (.executed(let agent), .executed):
            lastActionMessage = "\(agent.name) is ready."
            // Give first-time users a guided opening by seeding one discovery kickoff message.
            try? await withAuthorizedRetry(tokenProvider: requireToken) { token in
                _ = try await api.sendAgentConversationMessage(
                    token: token,
                    agentId: agent.id,
                    message: rotaryDiscoveryKickoffMessage(for: agent.name),
                    attachmentIds: [],
                    thinkingMode: thinkingMode
                )
            }
            await bootstrap(forceRefresh: true)
        default:
            lastActionMessage = "Agent setup queued offline and will complete when Rotary reconnects."
        }

        return createdAgent
    }

    private func rotaryDiscoveryKickoffMessage(for agentName: String) -> String {
        """
        Hi \(agentName). Let's do a quick setup chat so you can help me better over time.
        Ask me what I want help with most, how formal or casual you should sound, and what language style I prefer.
        Keep your questions short and one at a time.
        When speaking, use expressive delivery naturally, but never mirror frustration with frustrated delivery.
        If the other person sounds stressed, your voice should become calmer and more accommodating.
        """
    }

    func listVoicePresets() async throws -> [MobileVoicePreset] {
        if !cachedVoicePresets.isEmpty {
            return cachedVoicePresets
        }

        return try await refreshVoicePresets()
    }

    func refreshVoicePresets() async throws -> [MobileVoicePreset] {
        if let voicePresetTask {
            return try await voicePresetTask.value
        }

        let task = Task<[MobileVoicePreset], Error> {
            let response = try await withAuthorizedRetry(tokenProvider: requireToken) { token in
                try await api.voicePresets(token: token)
            }
            return response.voices
        }
        voicePresetTask = task

        do {
            let voices = try await task.value
            cachedVoicePresets = voices
            voicePresetTask = nil
            return voices
        } catch {
            voicePresetTask = nil
            if !cachedVoicePresets.isEmpty {
                return cachedVoicePresets
            }
            throw error
        }
    }

    func prewarmVoicePresets() async {
        _ = try? await refreshVoicePresets()
    }

    func createFolder(name: String, description: String?, color: String?) async throws {
        let tempID = "temp-folder:\(UUID().uuidString)"
        let result = try await mutationDispatcher.createFolder(
            tempID: tempID,
            name: name,
            description: description,
            color: color
        )
        switch result {
        case .executed:
            await bootstrap(forceRefresh: true)
        case .queued:
            lastActionMessage = "Folder queued offline."
        }
    }

    func renameFolder(id: String, name: String) async throws {
        let result = try await mutationDispatcher.updateFolder(
            folderId: id,
            name: name,
            description: nil,
            color: nil
        )
        switch result {
        case .executed:
            await bootstrap(forceRefresh: true)
        case .queued:
            lastActionMessage = "Folder rename queued offline."
        }
    }

    func searchContacts(query: String) async throws -> [MobileContactSearchResult] {
        let payload = try await withAuthorizedRetry(tokenProvider: requireToken) { token in
            try await api.searchContacts(token: token, query: query)
        }
        return payload.results
    }

    func createContact(name: String?, phoneNumber: String, email: String? = nil) async throws -> MobileCreatedContact {
        let tempID = "temp-contact:\(UUID().uuidString)"
        let result = try await mutationDispatcher.createContact(
            tempID: tempID,
            name: name,
            phoneNumber: phoneNumber,
            email: email,
            company: nil,
            fullAddress: nil,
            avatarURL: nil
        )

        switch result {
        case .executed(let payload):
            return payload.contact
        case .queued:
            lastActionMessage = "Contact queued offline."
            return MobileCreatedContact(
                id: tempID,
                name: name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? name! : phoneNumber,
                phone: phoneNumber,
                email: email,
                avatarUrl: nil,
                company: nil,
                fullAddress: nil
            )
        }
    }

    func messageFilters() async throws -> MobileThreadFilterCounts {
        try await withAuthorizedRetry(tokenProvider: requireToken) { token in
            try await api.messageFilters(token: token)
        }
    }

    func updateThreads(contactIds: [String], action: String) async throws {
        let result = try await mutationDispatcher.updateThreads(contactIds: contactIds, action: action)
        if case .queued = result {
            lastActionMessage = "Thread action queued offline."
        }
    }

    func callScreeningSettings() async throws -> MobileCallScreeningSettings {
        try await withAuthorizedRetry(tokenProvider: requireToken) { token in
            try await api.callScreeningSettings(token: token)
        }
    }

    func updateCallScreening(enabled: Bool) async throws -> MobileCallScreeningSettings {
        let result = try await mutationDispatcher.updateCallScreening(enabled: enabled)
        switch result {
        case .executed(let payload):
            return payload
        case .queued:
            lastActionMessage = "Call screening update queued offline."
            let line = cachedReadyState?.ownerLine
            return MobileCallScreeningSettings(
                enabled: enabled,
                lineId: line?.id ?? "pending-line",
                phoneNumber: line?.phoneNumber ?? cachedReadyState?.capabilities.defaultMainLine ?? "Unknown"
            )
        }
    }

    func markFirstRunOnboardingCompleted() {
        guard case let .ready(readyState) = phase else { return }
        firstRunOnboardingState.markCompleted(
            for: readyState.session.orgId,
            version: Self.firstRunOnboardingVersion
        )
        persistFirstRunOnboardingState()
    }

    func loadDeviceContactsForImport(limit: Int = 300) async -> [DeviceContactImportCandidate] {
        do {
            return try await contactsImportCoordinator.fetchCandidates(limit: limit)
        } catch {
            return []
        }
    }

    func importDeviceContacts(
        _ candidates: [DeviceContactImportCandidate],
        progress: ((Int, Int) -> Void)? = nil
    ) async -> DeviceContactsImportResult {
        guard !candidates.isEmpty else {
            return DeviceContactsImportResult()
        }

        var result = DeviceContactsImportResult()
        let total = candidates.count

        if ProcessInfo.processInfo.environment["ROTARY_USE_CACHED_BOOTSTRAP_ONLY"] == "1" {
            for index in candidates.indices {
                progress?(index + 1, total)
            }
            result.skipped = total
            return result
        }

        for (index, candidate) in candidates.enumerated() {
            do {
                let tempID = "import-contact:\(candidate.id)"
                let mutationResult = try await mutationDispatcher.createContact(
                    tempID: tempID,
                    name: candidate.name,
                    phoneNumber: candidate.phoneNumber,
                    email: candidate.email,
                    company: nil,
                    fullAddress: nil,
                    avatarURL: nil
                )
                switch mutationResult {
                case .executed:
                    result.created += 1
                case .queued:
                    result.queued += 1
                }
            } catch {
                result.failed += 1
            }

            progress?(index + 1, total)
        }

        return result
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

    private static func loadFirstRunOnboardingState() -> FirstRunOnboardingState {
        guard let data = UserDefaults.standard.data(forKey: firstRunOnboardingStateKey),
              let state = try? JSONDecoder().decode(FirstRunOnboardingState.self, from: data) else {
            return FirstRunOnboardingState()
        }
        return state
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

    private func persistFirstRunOnboardingState() {
        guard let data = try? JSONEncoder().encode(firstRunOnboardingState) else { return }
        UserDefaults.standard.set(data, forKey: Self.firstRunOnboardingStateKey)
    }
}
