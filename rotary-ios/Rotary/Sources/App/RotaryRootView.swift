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
private let rotaryDebugOpenCallsKeypadNotification = Notification.Name("rotary.debug.openCallsKeypad")
private let rotaryDebugOpenCallsKeypadWithDigitsNotification = Notification.Name("rotary.debug.openCallsKeypadWithDigits")
private let rotaryDebugCallsKeypadDeleteHoldNotification = Notification.Name("rotary.debug.callsKeypadDeleteHold")
private let rotaryDebugCallsOpenDialResultsNotification = Notification.Name("rotary.debug.callsOpenDialResults")
private let rotaryDebugSelectTabNotification = Notification.Name("rotary.debug.selectTab")
private let rotaryDebugPendingAgentWorkflowKey = "rotary.debug.pendingAgentWorkflowLaunch"

private struct RotaryPendingDebugAction: Decodable {
    let action: String
    let to: String?
    let body: String?
    let tab: String?
    let threadId: String?
    let agentId: String?
    let mode: String?
    let prompt: String?
    let autoApprove: Bool?
    let digits: String?
}

private struct RotaryPendingAgentWorkflowLaunch: Codable {
    let agentId: String
    let mode: String
    let prompt: String
    let autoApprove: Bool
    let requestedAt: Date
}
#endif

struct RotaryRootView: View {
    @Binding var appearanceMode: RotaryAppearanceMode
    @State private var authStore = RotaryAuthStore()
    @State private var appModel = AppModel()
    @State private var voiceCoordinator = VoiceCoordinator.shared
    @State private var debugLaunchActionHandled = false
    @State private var pendingDeepLink: RotaryDeepLink?

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
                voiceCoordinator: voiceCoordinator,
                pendingDeepLink: $pendingDeepLink
            )
            .fullScreenCover(
                isPresented: Binding(
                    get: { appModel.shouldShowFirstRunOnboarding },
                    set: { _ in }
                )
            ) {
                FirstRunOnboardingFlow(appModel: appModel)
            }
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
        if let deepLink = RotaryDeepLink.parse(url) {
            RotaryLogger.trace("routing deep link \(deepLink.routingKey)")
            pendingDeepLink = deepLink
            return
        }
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
        let workflowAgentId = environment["ROTARY_DEBUG_AGENT_ID"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? pendingFileAction?.agentId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let workflowMode = environment["ROTARY_DEBUG_MODE"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? pendingFileAction?.mode?.trimmingCharacters(in: .whitespacesAndNewlines)
        let workflowPrompt = environment["ROTARY_DEBUG_PROMPT"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? pendingFileAction?.prompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        let workflowAutoApprove = environment["ROTARY_DEBUG_AUTO_APPROVE"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? pendingFileAction?.autoApprove.map { $0 ? "true" : "false" }
        let debugTab = environment["ROTARY_DEBUG_TAB"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? pendingFileAction?.tab?.trimmingCharacters(in: .whitespacesAndNewlines)
        let debugThreadId = environment["ROTARY_DEBUG_THREAD_ID"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? pendingFileAction?.threadId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let debugDigits = pendingFileAction?.digits?.trimmingCharacters(in: .whitespacesAndNewlines)
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
            case "toggle_mute":
                try await runDebugToggleMute()
            case "toggle_hold":
                try await runDebugToggleHold()
            case "toggle_speaker":
                try await runDebugToggleSpeaker()
            case "open_live_assist":
                try await runDebugOpenLiveAssist()
            case "close_live_assist":
                try await runDebugCloseLiveAssist()
            case "open_keypad":
                try await runDebugOpenKeypad()
            case "close_keypad":
                try await runDebugCloseKeypad()
            case "open_calls_keypad":
                await runDebugOpenCallsKeypad(prefillDigits: (debugDigits?.isEmpty == false ? debugDigits! : nil))
            case "calls_keypad_delete_hold":
                await runDebugCallsKeypadDeleteHold(prefillDigits: (debugDigits?.isEmpty == false ? debugDigits! : nil))
            case "open_calls_dial_results":
                await runDebugOpenCallsDialResults(prefillDigits: (debugDigits?.isEmpty == false ? debugDigits! : nil))
            case "open_tab":
                await runDebugOpenTab((debugTab?.isEmpty == false ? debugTab! : "calls"))
            case "open_messages_thread":
                pendingDeepLink = .messagesThread(
                    threadID: (debugThreadId?.isEmpty == false ? debugThreadId! : "contact_sarah")
                )
                recordDebugResult("debug launch deep link queued: messages thread")
            case "open_agent":
                pendingDeepLink = .agentConversation(
                    agentID: (workflowAgentId?.isEmpty == false ? workflowAgentId! : "agent_concierge")
                )
                recordDebugResult("debug launch deep link queued: agent")
            case "open_calls_live_assist":
                pendingDeepLink = .callsLiveAssist(callID: nil)
                recordDebugResult("debug launch deep link queued: calls live assist")
            case "open_settings":
                pendingDeepLink = .settings
                recordDebugResult("debug launch deep link queued: settings")
            case "agent_workflow":
                await runDebugAgentWorkflow(
                    agentId: (workflowAgentId?.isEmpty == false ? workflowAgentId! : "agent_concierge"),
                    mode: (workflowMode?.isEmpty == false ? workflowMode! : "make_call"),
                    prompt: (workflowPrompt?.isEmpty == false ? workflowPrompt! : "I need lawn mowing done at my house tomorrow."),
                    autoApprove: normalizeDebugBoolean(workflowAutoApprove, defaultValue: true)
                )
            case "steer_queue":
                try await runDebugSteer(mode: "queue")
            case "steer_interrupt":
                try await runDebugSteer(mode: "interrupt")
            case "steer_mode":
                try await runDebugSteer(mode: "steer")
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
        let digits = queryItems.first(where: { $0.name == "digits" })?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let agentId = queryItems.first(where: { $0.name == "agentId" || $0.name == "agentID" })?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let workflowMode = queryItems.first(where: { $0.name == "mode" })?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let workflowPrompt = queryItems.first(where: { $0.name == "prompt" })?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let autoApproveRawValue = queryItems.first(where: { $0.name == "approve" || $0.name == "autoApprove" })?.value?
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
            case "/toggle-mute":
                try await runDebugToggleMute()
            case "/toggle-hold":
                try await runDebugToggleHold()
            case "/toggle-speaker":
                try await runDebugToggleSpeaker()
            case "/open-live-assist":
                try await runDebugOpenLiveAssist()
            case "/close-live-assist":
                try await runDebugCloseLiveAssist()
            case "/open-keypad":
                try await runDebugOpenKeypad()
            case "/close-keypad":
                try await runDebugCloseKeypad()
            case "/open-calls-keypad":
                await runDebugOpenCallsKeypad(prefillDigits: digits)
            case "/calls-keypad-delete-hold":
                await runDebugCallsKeypadDeleteHold(prefillDigits: digits)
            case "/open-calls-dial-results":
                await runDebugOpenCallsDialResults(prefillDigits: digits)
            case "/open-tab":
                if let tab = queryItems.first(where: { $0.name == "tab" })?.value {
                    await runDebugOpenTab(tab)
                }
            case "/agent-workflow":
                await runDebugAgentWorkflow(
                    agentId: (agentId?.isEmpty == false ? agentId! : "agent_concierge"),
                    mode: (workflowMode?.isEmpty == false ? workflowMode! : "make_call"),
                    prompt: (workflowPrompt?.isEmpty == false ? workflowPrompt! : "I need lawn mowing done at my house tomorrow."),
                    autoApprove: normalizeDebugBoolean(autoApproveRawValue, defaultValue: true)
                )
            case "/steer-queue":
                try await runDebugSteer(mode: "queue")
            case "/steer-interrupt":
                try await runDebugSteer(mode: "interrupt")
            case "/steer-mode":
                try await runDebugSteer(mode: "steer")
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

    @MainActor
    private func runDebugToggleMute() async throws {
        try ensureActiveDebugCall()
        voiceCoordinator.toggleMute()
        let message = voiceCoordinator.isMuted ? "Debug mute on" : "Debug mute off"
        appModel.lastActionMessage = message
        RotaryLogger.trace(message, category: "debug")
        recordDebugResult(message)
    }

    @MainActor
    private func runDebugToggleHold() async throws {
        try ensureActiveDebugCall()
        voiceCoordinator.toggleHold()
        let message = voiceCoordinator.isCallOnHold ? "Debug hold on" : "Debug hold off"
        appModel.lastActionMessage = message
        RotaryLogger.trace(message, category: "debug")
        recordDebugResult(message)
    }

    @MainActor
    private func runDebugToggleSpeaker() async throws {
        try ensureActiveDebugCall()
        voiceCoordinator.toggleSpeaker()
        let message = voiceCoordinator.isSpeakerEnabled ? "Debug speaker on" : "Debug speaker off"
        appModel.lastActionMessage = message
        RotaryLogger.trace(message, category: "debug")
        recordDebugResult(message)
    }

    @MainActor
    private func runDebugOpenLiveAssist() async throws {
        try ensureActiveDebugCall()
        voiceCoordinator.requestDebugLiveAssistSheetPresentation()
        let message = "Debug open live assist requested"
        appModel.lastActionMessage = message
        RotaryLogger.trace(message, category: "debug")
        recordDebugResult(message)
    }

    @MainActor
    private func runDebugCloseLiveAssist() async throws {
        try ensureActiveDebugCall()
        voiceCoordinator.requestDebugLiveAssistSheetDismissal()
        let message = "Debug close live assist requested"
        appModel.lastActionMessage = message
        RotaryLogger.trace(message, category: "debug")
        recordDebugResult(message)
    }

    @MainActor
    private func runDebugOpenKeypad() async throws {
        try ensureActiveDebugCall()
        voiceCoordinator.requestDebugKeypadPresentation()
        let message = "Debug open keypad requested"
        appModel.lastActionMessage = message
        RotaryLogger.trace(message, category: "debug")
        recordDebugResult(message)
    }

    @MainActor
    private func runDebugCloseKeypad() async throws {
        try ensureActiveDebugCall()
        voiceCoordinator.requestDebugKeypadDismissal()
        let message = "Debug close keypad requested"
        appModel.lastActionMessage = message
        RotaryLogger.trace(message, category: "debug")
        recordDebugResult(message)
    }

    @MainActor
    private func runDebugOpenCallsKeypad(prefillDigits: String? = nil) async {
        if let prefillDigits, !prefillDigits.isEmpty {
            NotificationCenter.default.post(
                name: rotaryDebugOpenCallsKeypadWithDigitsNotification,
                object: nil,
                userInfo: ["digits": prefillDigits]
            )
        } else {
            NotificationCenter.default.post(name: rotaryDebugOpenCallsKeypadNotification, object: nil)
        }
        let message = "Debug open calls keypad requested"
        appModel.lastActionMessage = message
        RotaryLogger.trace(message, category: "debug")
        recordDebugResult(message)
    }

    @MainActor
    private func runDebugCallsKeypadDeleteHold(prefillDigits: String? = nil) async {
        let digits = (prefillDigits?.isEmpty == false ? prefillDigits : nil) ?? "99999"
        NotificationCenter.default.post(
            name: rotaryDebugCallsKeypadDeleteHoldNotification,
            object: nil,
            userInfo: ["digits": digits]
        )
        let message = "Debug calls keypad delete-hold requested"
        appModel.lastActionMessage = message
        RotaryLogger.trace(message, category: "debug")
        recordDebugResult(message)
    }

    @MainActor
    private func runDebugOpenCallsDialResults(prefillDigits: String? = nil) async {
        let digits = (prefillDigits?.isEmpty == false ? prefillDigits : nil) ?? "9"
        NotificationCenter.default.post(
            name: rotaryDebugCallsOpenDialResultsNotification,
            object: nil,
            userInfo: ["digits": digits]
        )
        let message = "Debug calls dial-results requested"
        appModel.lastActionMessage = message
        RotaryLogger.trace(message, category: "debug")
        recordDebugResult(message)
    }

    @MainActor
    private func runDebugOpenTab(_ rawTab: String) async {
        let normalized = rawTab
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard ["calls", "messages", "agents", "0", "1", "2"].contains(normalized) else {
            recordDebugResult("error: unsupported tab \(rawTab)")
            return
        }

        NotificationCenter.default.post(
            name: rotaryDebugSelectTabNotification,
            object: nil,
            userInfo: ["tab": normalized]
        )
        let message = "Debug tab switch requested (\(normalized))"
        appModel.lastActionMessage = message
        RotaryLogger.trace(message, category: "debug")
        recordDebugResult(message)
    }

    @MainActor
    private func runDebugSteer(mode: String) async throws {
        try ensureActiveDebugCall()
        voiceCoordinator.requestDebugSteer(mode: mode)
        let message = "Debug steer requested (\(mode))"
        appModel.lastActionMessage = message
        RotaryLogger.trace(message, category: "debug")
        recordDebugResult(message)
    }

    @MainActor
    private func runDebugAgentWorkflow(
        agentId: String,
        mode: String,
        prompt: String,
        autoApprove: Bool
    ) async {
        let normalizedAgentId = agentId.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedMode = mode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedAgentId.isEmpty, !normalizedPrompt.isEmpty else {
            recordDebugResult("error: agent-workflow requires non-empty agentId and prompt")
            return
        }

        let pendingLaunch = RotaryPendingAgentWorkflowLaunch(
            agentId: normalizedAgentId,
            mode: normalizedMode,
            prompt: normalizedPrompt,
            autoApprove: autoApprove,
            requestedAt: Date()
        )

        do {
            let data = try JSONEncoder().encode(pendingLaunch)
            UserDefaults.standard.set(data, forKey: rotaryDebugPendingAgentWorkflowKey)
            pendingDeepLink = .agentConversation(agentID: normalizedAgentId)
            let message = "Debug agent workflow queued (\(normalizedMode)) for \(normalizedAgentId)"
            appModel.lastActionMessage = message
            RotaryLogger.trace(message, category: "debug")
            recordDebugResult(message)
        } catch {
            recordDebugResult("error: failed to encode pending agent workflow - \(error.localizedDescription)")
        }
    }

    private func normalizeDebugBoolean(_ rawValue: String?, defaultValue: Bool) -> Bool {
        guard let rawValue else { return defaultValue }
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "on":
            return true
        case "0", "false", "no", "n", "off":
            return false
        default:
            return defaultValue
        }
    }

    private func ensureActiveDebugCall() throws {
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
