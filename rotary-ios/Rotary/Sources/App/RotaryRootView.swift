import SwiftUI
import OSLog

#if DEBUG
private enum RotaryDebugActionError: LocalizedError {
    case notReady
    case unresolved(String)
    case missingNumber
    case noActiveCall
    case noPresentedCallScreen

    var errorDescription: String? {
        switch self {
        case .notReady:
            return "Rotary is not in a ready workspace state yet."
        case let .unresolved(state):
            return "Rotary did not reach a ready workspace state (\(state))."
        case .missingNumber:
            return "A valid destination number is required for this debug action."
        case .noActiveCall:
            return "Rotary does not have an active call to end."
        case .noPresentedCallScreen:
            return "Rotary does not have a visible call screen to minimize."
        }
    }
}

private let rotaryDebugLastActionDefaultsKey = "rotary.debug.lastAction"

private struct RotaryPendingDebugAction: Decodable {
    let action: String
    let to: String?
    let body: String?
}
#endif

struct RotaryRootView: View {
    @Binding var appearanceMode: RotaryAppearanceMode
    @State private var authStore = RotaryAuthStore()
    @State private var appModel = AppModel()
    @State private var voiceCoordinator = VoiceCoordinator.shared
    @State private var debugLaunchActionHandled = false

    var body: some View {
        rootContent
        .task {
            await restoreSession()
        }
        .task(id: authStore.authSyncKey) {
            await syncAuthToAppModel()
        }
        .onOpenURL { url in
            Task {
                await handleIncomingURL(url)
            }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        switch authStore.phase {
        case .loading:
            loadingScreen(title: "Loading Rotary", message: "Restoring your session and workspace.")
        case .signedOut:
            AuthScreen(authStore: authStore)
        case .signedIn:
            signedInContent
        }
    }

    @ViewBuilder
    private var signedInContent: some View {
        switch appModel.phase {
        case .authLoading, .bootstrapLoading:
            loadingScreen(title: "Preparing Rotary", message: "Loading your lines, agents, and message history.")
        case let .pending(notice):
            StatusScreen(kind: .pending, notice: notice) {
                Task { await appModel.bootstrap(forceRefresh: true) }
            } signOut: {
                Task { await appModel.signOut() }
            }
        case let .setupRequired(notice):
            OnboardingFlow(appModel: appModel, notice: notice)
        case let .blocked(error):
            StatusScreen(kind: .blocked(error.canRetry == false ? "Blocked" : "Unable to load"), error: error) {
                Task { await appModel.bootstrap(forceRefresh: true) }
            } signOut: {
                Task { await appModel.signOut() }
            }
        case let .ready(bootstrap):
            RotaryTabShell(
                appearanceMode: $appearanceMode,
                appModel: appModel,
                bootstrap: bootstrap,
                voiceCoordinator: voiceCoordinator
            )
        }
    }

    private func loadingScreen(title: String, message: String) -> some View {
        RotaryCenteredShell {
            RotaryGlassCard {
                Circle()
                    .fill(RotaryTheme.softSurface)
                    .frame(width: 74, height: 74)
                    .overlay(
                        Image(systemName: "phone.badge.waveform.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.secondary)
                    )
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(message)
                    .foregroundStyle(.secondary)
                if let cachedReadyState = appModel.cachedReadyState {
                    HStack(spacing: 8) {
                        RotaryPill(text: "\(cachedReadyState.lines.count) lines", active: false)
                        RotaryPill(text: "\(cachedReadyState.agents.count) agents", active: false)
                        RotaryPill(text: "\(cachedReadyState.threadPreview.count) chats", active: false)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    @MainActor
    private func restoreSession() async {
        await authStore.restore()
    }

    @MainActor
    private func syncAuthToAppModel() async {
        let tokenProvider: RotaryTokenProvider?
        if authStore.sessionToken == nil {
            tokenProvider = nil
        } else {
            tokenProvider = { forceRefresh in
                try await authStore.freshSessionToken(forceRefresh: forceRefresh)
            }
        }

        appModel.configureAuthentication(
            tokenProvider: tokenProvider,
            signOutHandler: { await authStore.signOut() }
        )

        if authStore.sessionToken != nil {
            await appModel.bootstrap()
#if DEBUG
            await runDebugLaunchActionIfNeeded()
#endif
        } else {
            voiceCoordinator.clearSession()
            await appModel.resetForSignedOut()
        }
    }

    private func handleIncomingURL(_ url: URL) async {
        RotaryLogger.trace("handleIncomingURL \(url.absoluteString)")
#if DEBUG
        if await handleDebugURL(url) {
            return
        }
#endif
        let expectedCallbackURL = AppConfig.shared.hostedClerkCallbackURL()
        guard matchesHostedAuthCallback(url, expected: expectedCallbackURL) else {
            RotaryLogger.trace("incoming url ignored because it does not match hosted auth callback")
            return
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            RotaryLogger.trace("incoming url could not be parsed")
            return
        }

        let ticket = components.queryItems?.first(where: {
            $0.name == "ticket" || $0.name == "__clerk_ticket"
        })?.value
        guard let ticket, !ticket.isEmpty else {
            RotaryLogger.trace("incoming url missing ticket")
            return
        }

        do {
            RotaryLogger.trace("starting ticket sign-in from url")
            try await authStore.signIn(ticket: ticket)
            RotaryLogger.trace("ticket sign-in finished")
        } catch {
            RotaryLogger.auth.error("Ticket sign-in failed: \(error.localizedDescription, privacy: .public)")
            RotaryLogger.trace("ticket sign-in failed: \(error.localizedDescription)")
        }
    }

    private func matchesHostedAuthCallback(_ url: URL, expected: URL) -> Bool {
        let incomingScheme = url.scheme?.lowercased()
        let expectedScheme = expected.scheme?.lowercased()
        guard incomingScheme == expectedScheme else {
            return false
        }

        let incomingHost = url.host?.lowercased()
        let expectedHost = expected.host?.lowercased()
        guard incomingHost == expectedHost else {
            return false
        }

        return normalizedCallbackPath(url.path) == normalizedCallbackPath(expected.path)
    }

    private func normalizedCallbackPath(_ path: String) -> String {
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmedPath.lowercased()
    }

#if DEBUG
    @MainActor
    private func runDebugLaunchActionIfNeeded() async {
        guard !debugLaunchActionHandled else { return }

        let environment = ProcessInfo.processInfo.environment
        let actionKeys = environment.keys
            .filter { $0.hasPrefix("ROTARY_DEBUG_") }
            .sorted()
        if !actionKeys.isEmpty {
            recordDebugResult("debug launch environment keys: \(actionKeys.joined(separator: ","))")
        }

        let pendingFileAction = loadPendingDebugFileAction()
        let action = environment["ROTARY_DEBUG_ACTION"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? pendingFileAction?.action.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let action, !action.isEmpty else {
            return
        }

        debugLaunchActionHandled = true
        let destination = environment["ROTARY_DEBUG_TO"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? pendingFileAction?.to?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = environment["ROTARY_DEBUG_BODY"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? pendingFileAction?.body?.trimmingCharacters(in: .whitespacesAndNewlines)
        recordDebugResult("debug launch action received: \(action)")

        do {
            switch action {
            case "send_sms":
                guard let destination, !destination.isEmpty else {
                    throw RotaryDebugActionError.missingNumber
                }
                try await runDebugSendSMS(
                    to: destination,
                    body: body?.isEmpty == false ? body! : "Rotary native launch SMS self-test."
                )
            case "call":
                guard let destination, !destination.isEmpty else {
                    throw RotaryDebugActionError.missingNumber
                }
                try await runDebugCall(to: destination)
            case "preview_call":
                await runDebugPreviewCall(handle: destination)
            case "minimize_call":
                try await runDebugMinimizeCall()
            case "restore_call":
                try await runDebugRestoreCall()
            case "end_call":
                try await runDebugEndCall()
            default:
                recordDebugResult("error: unsupported debug action \(action)")
            }
        } catch {
            RotaryLogger.trace("debug launch action failed: \(error.localizedDescription)", category: "debug", level: "error")
            appModel.lastActionMessage = error.localizedDescription
            recordDebugResult("error: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func handleDebugURL(_ url: URL) async -> Bool {
        guard url.host == "debug",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }

        recordDebugResult("debug url received: \(url.absoluteString)")
        let queryItems = components.queryItems ?? []
        let destination = queryItems.first(where: { $0.name == "to" })?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let body = queryItems.first(where: { $0.name == "body" })?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let actionPath = components.path

        do {
            switch actionPath {
            case "/send-sms":
                guard let destination, !destination.isEmpty else {
                    throw RotaryDebugActionError.missingNumber
                }
                try await runDebugSendSMS(
                    to: destination,
                    body: body?.isEmpty == false ? body! : "Rotary native debug SMS self-test."
                )
            case "/call":
                guard let destination, !destination.isEmpty else {
                    throw RotaryDebugActionError.missingNumber
                }
                try await runDebugCall(to: destination)
            case "/preview-call":
                await runDebugPreviewCall(handle: destination)
            case "/minimize-call":
                try await runDebugMinimizeCall()
            case "/restore-call":
                try await runDebugRestoreCall()
            case "/end-call":
                try await runDebugEndCall()
            default:
                RotaryLogger.trace("debug url ignored path=\(actionPath)")
            }
        } catch {
            RotaryLogger.trace("debug action failed: \(error.localizedDescription)", category: "debug", level: "error")
            appModel.lastActionMessage = error.localizedDescription
            recordDebugResult("error: \(error.localizedDescription)")
        }

        return true
    }

    @MainActor
    private func resolveReadyBootstrap() async throws -> MobileBootstrapReadyState {
        if case let .ready(bootstrap) = appModel.phase {
            return bootstrap
        }

        await appModel.bootstrap(forceRefresh: true)

        if case let .ready(bootstrap) = appModel.phase {
            return bootstrap
        }

        let phaseSummary: String = switch appModel.phase {
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
        throw RotaryDebugActionError.unresolved(phaseSummary)
    }

    @MainActor
    private func runDebugSendSMS(to destination: String, body: String) async throws {
        let bootstrap = try await resolveReadyBootstrap()
        let token = try await appModel.token(forceRefresh: true)
        let fromNumber = bootstrap.ownerLine?.phoneNumber ?? bootstrap.capabilities.defaultMainLine
        let response = try await appModel.apiClient.sendMessage(
            token: token,
            contactId: nil,
            toNumber: destination,
            fromNumber: fromNumber,
            message: body
        )

        let messageId = response.messageId ?? "unknown"
        let message = "Debug SMS sent to \(destination) with id \(messageId)"
        appModel.lastActionMessage = message
        RotaryLogger.trace(message, category: "debug")
        recordDebugResult(message)
    }

    @MainActor
    private func runDebugCall(to destination: String) async throws {
        let bootstrap = try await resolveReadyBootstrap()
        let token = try await appModel.token(forceRefresh: true)
        let tokenProvider: RotaryTokenProvider = { forceRefresh in
            try await appModel.token(forceRefresh: forceRefresh)
        }
        await voiceCoordinator.configureSession(
            authToken: token,
            bootstrap: bootstrap,
            tokenProvider: tokenProvider
        )
        try await voiceCoordinator.startOwnerCall(to: destination, handle: destination)

        let message = "Debug call started to \(destination)"
        appModel.lastActionMessage = message
        RotaryLogger.trace(message, category: "debug")
        recordDebugResult(message)
    }

    @MainActor
    private func runDebugEndCall() async throws {
        let hasPresentedCall: Bool
        switch voiceCoordinator.callPresentationState {
        case .requestingCallKit, .startedConnecting, .ringing, .connected:
            hasPresentedCall = true
        case .idle, .ended, .failed:
            hasPresentedCall = false
        }

        guard hasPresentedCall ||
                voiceCoordinator.isInCall ||
                voiceCoordinator.activeCallUUID != nil ||
                voiceCoordinator.activeCallbackCallSid != nil else {
            throw RotaryDebugActionError.noActiveCall
        }

        voiceCoordinator.endCurrentCall()
        let message = "Debug end call requested"
        appModel.lastActionMessage = message
        RotaryLogger.trace(message, category: "debug")
        recordDebugResult(message)
    }

    @MainActor
    private func runDebugPreviewCall(handle: String?) async {
        let title = handle?.trimmingCharacters(in: .whitespacesAndNewlines)
        voiceCoordinator.showDebugPreviewCall(handle: title?.isEmpty == false ? title! : "Rotary Preview Call")
        let message = "Debug preview call presented"
        appModel.lastActionMessage = message
        RotaryLogger.trace(message, category: "debug")
        recordDebugResult(message)
    }

    @MainActor
    private func runDebugMinimizeCall() async throws {
        guard voiceCoordinator.isCallScreenPresented else {
            throw RotaryDebugActionError.noPresentedCallScreen
        }

        voiceCoordinator.minimizeCallScreen()
        let message = "Debug minimize call requested"
        appModel.lastActionMessage = message
        RotaryLogger.trace(message, category: "debug")
        recordDebugResult(message)
    }

    @MainActor
    private func runDebugRestoreCall() async throws {
        let hasPresentedCall: Bool
        switch voiceCoordinator.callPresentationState {
        case .requestingCallKit, .startedConnecting, .ringing, .connected:
            hasPresentedCall = true
        case .idle, .ended, .failed:
            hasPresentedCall = false
        }

        guard hasPresentedCall else {
            throw RotaryDebugActionError.noActiveCall
        }

        voiceCoordinator.restoreCallScreen()
        let message = "Debug restore call requested"
        appModel.lastActionMessage = message
        RotaryLogger.trace(message, category: "debug")
        recordDebugResult(message)
    }

    private func recordDebugResult(_ message: String) {
        UserDefaults.standard.set(
            "[\(ISO8601DateFormatter().string(from: Date()))] \(message)",
            forKey: rotaryDebugLastActionDefaultsKey
        )
    }

    private func loadPendingDebugFileAction() -> RotaryPendingDebugAction? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rotary-debug-action.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        defer {
            try? FileManager.default.removeItem(at: url)
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(RotaryPendingDebugAction.self, from: data)
            recordDebugResult("debug file action received: \(decoded.action)")
            return decoded
        } catch {
            recordDebugResult("error: failed to decode debug file action - \(error.localizedDescription)")
            return nil
        }
    }
#endif
}
