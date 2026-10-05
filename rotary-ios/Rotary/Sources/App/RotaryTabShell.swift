import SwiftUI

private let rotaryDebugSelectTabNotification = Notification.Name("rotary.debug.selectTab")

private struct RotaryCallAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private enum RotaryLanguageCopy {
    static var isKorean: Bool {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("ko") == true
    }

    static func text(_ english: String, _ korean: String) -> String {
        isKorean ? korean : english
    }
}

private struct RotaryCallStatusChip: View {
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)

            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct RotaryCallPanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let alignment: HorizontalAlignment
    let spacing: CGFloat
    let cornerRadius: CGFloat
    @ViewBuilder let content: Content

    init(
        alignment: HorizontalAlignment = .leading,
        spacing: CGFloat = 16,
        cornerRadius: CGFloat = 30,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: spacing) {
                    panelBody
                        .glassEffect(
                            .regular.tint(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.13)).interactive(false),
                            in: .rect(cornerRadius: cornerRadius)
                        )
                }
            } else {
                panelBody
                    .background(
                        RotaryTheme.secondarySurface,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(RotaryTheme.cardStroke, lineWidth: 1)
                    )
            }
        }
    }

    private var panelBody: some View {
        VStack(alignment: alignment, spacing: spacing) {
            content
        }
        .padding(22)
        .background(
            Color.white.opacity(colorScheme == .dark ? 0.015 : 0.16),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .shadow(color: RotaryTheme.shadow.opacity(colorScheme == .dark ? 0.15 : 0.08), radius: 10, x: 0, y: 5)
    }
}

private struct RotaryCallAvatarBadge: View {
    let title: String
    let size: CGFloat
    let namespace: Namespace.ID

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                Circle()
                    .fill(.clear)
                    .glassEffect(
                        .regular.tint(RotaryTheme.callAccent.opacity(0.24)).interactive(false),
                        in: .circle
                    )
                    .glassEffectID("rotary-call-avatar", in: namespace)
                    .overlay(
                        RotaryAvatarView(title: title, size: size * 0.64)
                    )
            } else {
                Circle()
                    .fill(RotaryTheme.softSurface)
                    .overlay(
                        RotaryAvatarView(title: title, size: size * 0.64)
                    )
                    .overlay(
                        Circle()
                            .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
                    )
            }
        }
        .frame(width: size, height: size)
        .shadow(color: RotaryTheme.shadow.opacity(0.12), radius: 10, x: 0, y: 5)
    }
}

private struct RotaryCallActionTile: View {
    let title: String
    let systemImage: String
    let active: Bool
    let tint: Color
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                symbol

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(active ? tint : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.52)
    }

    @ViewBuilder
    private var symbol: some View {
        ZStack {
            Circle()
                .fill(active ? tint.opacity(0.28) : RotaryTheme.elevatedSurface.opacity(0.96))

            Circle()
                .stroke(active ? tint.opacity(0.34) : RotaryTheme.elevatedStroke, lineWidth: 1)

            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(symbolForeground)
        }
        .frame(width: 66, height: 66)
        .shadow(color: RotaryTheme.shadow.opacity(0.10), radius: 6, x: 0, y: 3)
    }

    private var symbolForeground: Color {
        active ? .white : .primary
    }
}

private extension RotaryCallPresentationState {
    var presentsActiveCallScreen: Bool {
        switch self {
        case .requestingCallKit, .startedConnecting, .ringing, .connected:
            return true
        case .idle, .ended, .failed:
            return false
        }
    }

    var statusTitle: String {
        switch self {
        case .requestingCallKit:
            return RotaryLanguageCopy.text("Starting Call", "통화 시작 중")
        case .startedConnecting:
            return RotaryLanguageCopy.text("Calling", "전화 거는 중")
        case .ringing:
            return RotaryLanguageCopy.text("Ringing", "벨이 울리는 중")
        case .connected:
            return RotaryLanguageCopy.text("On Call", "통화 중")
        case .ended:
            return RotaryLanguageCopy.text("Call Ended", "통화 종료")
        case .idle:
            return RotaryLanguageCopy.text("Phone", "전화")
        case .failed:
            return RotaryLanguageCopy.text("Call Failed", "통화 실패")
        }
    }
}

private enum LiveSteerMode: String, CaseIterable, Identifiable {
    case interrupt
    case steer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .interrupt:
            return "Interrupt"
        case .steer:
            return "Steer"
        }
    }

    var systemImage: String {
        switch self {
        case .interrupt:
            return "bolt.fill"
        case .steer:
            return "arrowshape.turn.up.right.fill"
        }
    }

    var assistantHint: String {
        switch self {
        case .interrupt:
            return "Cuts in immediately with your instruction."
        case .steer:
            return "Lets Rotary continue while following your direction."
        }
    }

    var shouldAutoApplyRecommended: Bool {
        self == .steer
    }
}

struct RotaryTabShell: View {
    @Binding var appearanceMode: RotaryAppearanceMode
    let appModel: AppModel
    let bootstrap: MobileBootstrapReadyState
    @Bindable var voiceCoordinator: VoiceCoordinator
    @Binding var pendingDeepLink: RotaryDeepLink?
    @Namespace private var callSurfaceNamespace

    @State private var messagesStore: MessagesStore
    @State private var callsStore: CallsStore
    @State private var selectedTab = 0
    @State private var showingSettings = false
    @State private var activeLiveAssistCall: MobileCall?
    @State private var liveAssistSheetCall: MobileCall?
    @State private var callAlert: RotaryCallAlert?
    @State private var rawMissedCallCount = 0
    @State private var acknowledgedMissedCallCount = 0
    @State private var isViewingMissedCalls = false
    @State private var rawUnreadMessageCount = 0
    @State private var acknowledgedUnreadMessageCount = 0
    @State private var rawAgentActivityCount = 0
    @State private var acknowledgedAgentActivityCount = 0
    @State private var pendingMessagesThreadID: String?
    @State private var pendingAgentID: String?

    init(
        appearanceMode: Binding<RotaryAppearanceMode>,
        appModel: AppModel,
        bootstrap: MobileBootstrapReadyState,
        voiceCoordinator: VoiceCoordinator,
        pendingDeepLink: Binding<RotaryDeepLink?>
    ) {
        _appearanceMode = appearanceMode
        self.appModel = appModel
        self.bootstrap = bootstrap
        self.voiceCoordinator = voiceCoordinator
        _pendingDeepLink = pendingDeepLink

        let tokenProvider: RotaryTokenProvider = { forceRefresh in
            try await appModel.token(forceRefresh: forceRefresh)
        }

        _messagesStore = State(initialValue: MessagesStore(
            bootstrap: bootstrap,
            api: appModel.apiClient,
            tokenProvider: tokenProvider,
            mutationDispatcher: appModel.mutationDispatcher
        ))
        _callsStore = State(initialValue: CallsStore(
            bootstrap: bootstrap,
            api: appModel.apiClient,
            tokenProvider: tokenProvider
        ))
    }

    private var tokenProvider: RotaryTokenProvider {
        { forceRefresh in
            try await appModel.token(forceRefresh: forceRefresh)
        }
    }

    private var storeSyncSignature: String {
        [
            bootstrap.session.orgId,
            "\(bootstrap.threadPreview.count)",
            bootstrap.threadPreview.first?.lastMessageAt ?? "",
            "\(bootstrap.callPreview.count)",
            bootstrap.callPreview.first?.updatedAt ?? "",
            "\(bootstrap.agents.count)",
        ]
        .joined(separator: "|")
    }

    private var voiceSessionSignature: String {
        [
            bootstrap.session.orgId,
            bootstrap.ownerLine?.id ?? "",
            bootstrap.ownerLine?.phoneNumber ?? "",
            bootstrap.ownerLine?.updatedAt ?? "",
        ]
        .joined(separator: "|")
    }

    private var displayedMissedCallBadgeCount: Int {
        if selectedTab == 0 && isViewingMissedCalls {
            return 0
        }
        return max(rawMissedCallCount - acknowledgedMissedCallCount, 0)
    }

    private var displayedUnreadMessageBadgeCount: Int {
        max(rawUnreadMessageCount - acknowledgedUnreadMessageCount, 0)
    }

    private var displayedAgentActivityBadgeCount: Int {
        max(rawAgentActivityCount - acknowledgedAgentActivityCount, 0)
    }

    var body: some View {
        let callPresentationState = voiceCoordinator.callPresentationState
        let isCallScreenPresented = voiceCoordinator.isCallScreenPresented
        let showsMinimizedCallBanner = callPresentationState.presentsActiveCallScreen && !isCallScreenPresented

        ZStack {
            TabView(selection: $selectedTab) {
                CallsScreen(
                    bootstrap: bootstrap,
                    store: callsStore,
                    messagesStore: messagesStore,
                    api: appModel.apiClient,
                    tokenProvider: tokenProvider,
                    showSettings: { showingSettings = true },
                    startCall: { call in
                        Task { await startCall(for: call) }
                    },
                    startManualCall: { phoneNumber, fromNumber in
                        Task { await startManualCall(phoneNumber: phoneNumber, fromNumber: fromNumber) }
                    },
                    openLiveAssist: { call in
                        if call.shouldShowLiveSteerControls {
                            liveAssistSheetCall = call
                        }
                    },
                    onMissedCallCountChange: { handleMissedCallCountUpdate($0) },
                    onViewingMissedCallsChange: { isViewing in
                        isViewingMissedCalls = isViewing
                        if isViewing, selectedTab == 0 {
                            acknowledgeMissedCalls()
                        }
                    }
                )
                .tabItem {
                    Label("Calls", systemImage: "phone.fill")
                }
                .badge(displayedMissedCallBadgeCount > 0 ? displayedMissedCallBadgeCount : 0)
                .tag(0)

                RotaryMessagesScreen(
                    bootstrap: bootstrap,
                    store: messagesStore,
                    startCall: { phoneNumber, fromNumber in
                        Task { await startManualCall(phoneNumber: phoneNumber, fromNumber: fromNumber) }
                    },
                    onUnreadCountChange: { handleUnreadMessageCountUpdate($0) },
                    pendingThreadID: $pendingMessagesThreadID
                )
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
                .badge(displayedUnreadMessageBadgeCount > 0 ? displayedUnreadMessageBadgeCount : 0)
                .tag(1)

                AgentsScreen(
                    bootstrap: bootstrap,
                    appModel: appModel,
                    api: appModel.apiClient,
                    messagesStore: messagesStore,
                    callsStore: callsStore,
                    voiceCoordinator: voiceCoordinator,
                    mutationDispatcher: appModel.mutationDispatcher,
                    refresh: { Task { await appModel.bootstrap(forceRefresh: true) } },
                    onActivityCountChange: { handleAgentActivityCountUpdate($0) },
                    pendingAgentID: $pendingAgentID
                )
                .tabItem {
                    Label("Agents", systemImage: "person.2.fill")
                }
                .badge(displayedAgentActivityBadgeCount > 0 ? displayedAgentActivityBadgeCount : 0)
                .tag(2)
            }
            .tint(RotaryTheme.accent)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(Color(uiColor: .systemBackground), for: .tabBar)
            .fullScreenCover(isPresented: $showingSettings) {
                SettingsSheet(
                    appearanceMode: $appearanceMode,
                    appModel: appModel,
                    bootstrap: bootstrap,
                    voiceCoordinator: voiceCoordinator,
                    mutationDispatcher: appModel.mutationDispatcher,
                    inferenceModeStore: appModel.inferenceModeStore
                )
            }
            .sheet(item: $liveAssistSheetCall) { call in
                LiveAssistSheet(
                    call: call,
                    api: appModel.apiClient,
                    voiceCoordinator: voiceCoordinator,
                    tokenProvider: tokenProvider
                )
            }
            .alert(item: $callAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .task(id: storeSyncSignature) {
                messagesStore.applyBootstrap(bootstrap)
                callsStore.applyBootstrap(bootstrap)
                handleMissedCallCountUpdate(callsStore.missedCallCount)
                handleUnreadMessageCountUpdate(messagesStore.unreadCount())
            }
            .task(id: voiceSessionSignature) {
                do {
                    let token = try await appModel.token()
                    await voiceCoordinator.configureSession(
                        authToken: token,
                        bootstrap: bootstrap,
                        tokenProvider: tokenProvider
                    )
                } catch {
                    voiceCoordinator.lastError = error.localizedDescription
                }
            }
            .task(id: callPresentationState) {
                updateActiveCallPresentation(for: callPresentationState)
            }
            .task(id: voiceCoordinator.activeSessionTrackingKey) {
                await monitorObservedCall()
            }
            .task(id: pendingDeepLink?.routingKey) {
                await handlePendingDeepLink()
            }
            .onChange(of: callPresentationState) { oldValue, newValue in
                updateActiveCallPresentation(for: newValue)

                if newValue.presentsActiveCallScreen {
                    Task {
                        await warmActiveCallSurface()
                    }
                }

                if case let .failed(message) = newValue {
                    callAlert = RotaryCallAlert(
                        title: "Call Failed",
                        message: message
                    )
                }
            }
            .onChange(of: selectedTab) { _, newValue in
                switch newValue {
                case 0:
                    if isViewingMissedCalls {
                        acknowledgeMissedCalls()
                    }
                case 1:
                    acknowledgeMessages()
                case 2:
                    acknowledgeAgentActivity()
                default:
                    break
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: rotaryDebugSelectTabNotification)) { notification in
                guard let rawTab = notification.userInfo?["tab"] as? String else { return }
                let normalized = rawTab.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                switch normalized {
                case "calls", "0":
                    selectedTab = 0
                case "messages", "1":
                    selectedTab = 1
                case "agents", "2":
                    selectedTab = 2
                default:
                    break
                }
            }
            .zIndex(0)

            if showsMinimizedCallBanner {
                VStack {
                    Spacer()
                    RotaryMinimizedCallBanner(
                        voiceCoordinator: voiceCoordinator,
                        observedCall: activeLiveAssistCall,
                        glassNamespace: callSurfaceNamespace
                    ) {
                        voiceCoordinator.restoreCallScreen()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 92)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }

            if isCallScreenPresented {
                RotaryActiveCallScreen(
                    voiceCoordinator: voiceCoordinator,
                    activeLiveAssistCall: activeLiveAssistCall,
                    api: appModel.apiClient,
                    tokenProvider: tokenProvider,
                    glassNamespace: callSurfaceNamespace,
                    dismiss: { voiceCoordinator.minimizeCallScreen() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .animation(.snappy(duration: 0.28, extraBounce: 0.05), value: isCallScreenPresented)
    }

    private func handleMissedCallCountUpdate(_ count: Int) {
        rawMissedCallCount = max(count, 0)
        if acknowledgedMissedCallCount > rawMissedCallCount {
            acknowledgedMissedCallCount = rawMissedCallCount
        }
        if selectedTab == 0, isViewingMissedCalls {
            acknowledgeMissedCalls()
        }
    }

    private func handleUnreadMessageCountUpdate(_ count: Int) {
        rawUnreadMessageCount = max(count, 0)
        if acknowledgedUnreadMessageCount > rawUnreadMessageCount {
            acknowledgedUnreadMessageCount = rawUnreadMessageCount
        }
        if selectedTab == 1 {
            acknowledgeMessages()
        }
    }

    private func handleAgentActivityCountUpdate(_ count: Int) {
        rawAgentActivityCount = max(count, 0)
        if acknowledgedAgentActivityCount > rawAgentActivityCount {
            acknowledgedAgentActivityCount = rawAgentActivityCount
        }
        if selectedTab == 2 {
            acknowledgeAgentActivity()
        }
    }

    private func acknowledgeMissedCalls() {
        acknowledgedMissedCallCount = rawMissedCallCount
    }

    private func acknowledgeMessages() {
        acknowledgedUnreadMessageCount = rawUnreadMessageCount
    }

    private func acknowledgeAgentActivity() {
        acknowledgedAgentActivityCount = rawAgentActivityCount
    }

    private func handlePendingDeepLink() async {
        guard let pendingDeepLink else { return }

        switch pendingDeepLink {
        case .calls:
            selectedTab = 0
        case let .callsLiveAssist(callID):
            selectedTab = 0
            await openLiveAssist(for: callID)
        case let .messagesThread(threadID):
            selectedTab = 1
            pendingMessagesThreadID = threadID
        case let .agentConversation(agentID):
            selectedTab = 2
            pendingAgentID = agentID
        case .settings:
            showingSettings = true
        }

        self.pendingDeepLink = nil
    }

    private func openLiveAssist(for callID: String?) async {
        if let activeLiveAssistCall,
           callID == nil || activeLiveAssistCall.id == callID || activeLiveAssistCall.callSid == callID {
            liveAssistSheetCall = activeLiveAssistCall
            return
        }

        _ = await callsStore.loadCalls(forceRefresh: true)

        let matchedCall = callsStore.allCalls.first { call in
            guard let callID else {
                return call.shouldShowLiveSteerControls
            }
            return call.id == callID || call.callSid == callID
        }

        guard let matchedCall, matchedCall.shouldShowLiveSteerControls else {
            callAlert = RotaryCallAlert(
                title: "Call Not Available",
                message: "Rotary could not find a live assist call for that notification."
            )
            return
        }

        activeLiveAssistCall = matchedCall
        voiceCoordinator.syncObservedCallRecord(matchedCall)
        liveAssistSheetCall = matchedCall
    }

    private func startCall(for call: MobileCall) async {
        let destination = call.contactPhone ?? call.toNumber ?? call.fromNumber ?? ""
        let handle = call.contactName.isEmpty ? destination : call.contactName
        await placeNativeCall(
            to: destination,
            fromNumber: bootstrap.ownerLine?.phoneNumber ?? bootstrap.capabilities.defaultMainLine,
            contactId: call.contactId,
            contactName: handle
        )
    }

    private func startManualCall(phoneNumber: String, fromNumber: String?) async {
        await placeNativeCall(
            to: phoneNumber,
            fromNumber: fromNumber ?? bootstrap.ownerLine?.phoneNumber ?? bootstrap.capabilities.defaultMainLine,
            contactId: nil,
            contactName: nil
        )
    }

    private func placeNativeCall(
        to phoneNumber: String,
        fromNumber: String?,
        contactId: String?,
        contactName: String?
    ) async {
        let trimmedPhoneNumber = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhoneNumber.isEmpty else {
            callAlert = RotaryCallAlert(
                title: "Enter a Number",
                message: "Type or select a phone number before placing the call."
            )
            RotaryHaptics.warning()
            return
        }

        let lineId = preferredLineId(for: fromNumber ?? bootstrap.ownerLine?.phoneNumber ?? bootstrap.capabilities.defaultMainLine)
            ?? bootstrap.ownerLine?.id

        guard let lineId else {
            callAlert = RotaryCallAlert(
                title: "Calling Unavailable",
                message: "Rotary could not find a valid outgoing line for this call."
            )
            RotaryHaptics.error()
            return
        }

        do {
            try await voiceCoordinator.startLineCall(
                to: trimmedPhoneNumber,
                lineId: lineId,
                handle: contactName ?? trimmedPhoneNumber,
                contactId: contactId,
                contactName: contactName
            )
            Task {
                await warmActiveCallSurface()
            }
            selectedTab = 0
            RotaryHaptics.softTap()
        } catch {
            voiceCoordinator.lastError = error.localizedDescription
            callAlert = RotaryCallAlert(
                title: "Native Calling Not Ready",
                message: error.localizedDescription
            )
            RotaryHaptics.error()
        }
    }

    private func preferredLineId(for phoneNumber: String?) -> String? {
        guard let phoneNumber else { return nil }
        let normalized = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return bootstrap.lines.first(where: { $0.phoneNumber == normalized })?.id
    }

    private func updateActiveCallPresentation(for newValue: RotaryCallPresentationState) {
#if DEBUG
        RotaryLogger.trace(
            "tab shell updateActiveCallPresentation state=\(newValue.statusTitle) presented=\(voiceCoordinator.isCallScreenPresented)",
            category: "voice"
        )
#endif
        if newValue.presentsActiveCallScreen {
            selectedTab = 0
            return
        }
        if case .ended = newValue {
            activeLiveAssistCall = nil
            liveAssistSheetCall = nil
        }
        if case .failed = newValue {
            activeLiveAssistCall = nil
            liveAssistSheetCall = nil
        }
    }

    private func monitorObservedCall() async {
        guard voiceCoordinator.callPresentationState.presentsActiveCallScreen else {
            activeLiveAssistCall = nil
            liveAssistSheetCall = nil
            return
        }

        for interval in [Duration.zero, .milliseconds(350), .milliseconds(750)] {
            if interval != .zero {
                try? await Task.sleep(for: interval)
            }
            guard !Task.isCancelled, voiceCoordinator.callPresentationState.presentsActiveCallScreen else {
                return
            }
            await refreshObservedCall(forceRefresh: true)
        }

        while !Task.isCancelled && voiceCoordinator.callPresentationState.presentsActiveCallScreen {
            try? await Task.sleep(for: .seconds(1))
            await refreshObservedCall(forceRefresh: true)
        }
    }

    private func warmActiveCallSurface() async {
        let cadence: [Duration] = [.zero, .milliseconds(300), .milliseconds(700), .seconds(1)]
        for interval in cadence {
            if interval != .zero {
                try? await Task.sleep(for: interval)
            }
            guard !Task.isCancelled, voiceCoordinator.callPresentationState.presentsActiveCallScreen else {
                return
            }
            await refreshObservedCall(forceRefresh: true)
            if activeLiveAssistCall != nil {
                return
            }
        }
    }

    private func refreshObservedCall(forceRefresh: Bool) async {
        _ = await callsStore.loadCalls(forceRefresh: forceRefresh)
        let observedCall = voiceCoordinator.matchingObservedCall(in: callsStore.allCalls)
        var matchedCall = observedCall?.shouldShowLiveSteerControls == true ? observedCall : nil
#if DEBUG
        if matchedCall == nil, voiceCoordinator.isDebugPreviewCallSession {
            matchedCall = debugSyntheticLiveAssistCall()
        }
#endif
        activeLiveAssistCall = matchedCall
        voiceCoordinator.syncObservedCallRecord(matchedCall)
    }

#if DEBUG
    private func debugSyntheticLiveAssistCall() -> MobileCall? {
        guard voiceCoordinator.callPresentationState.presentsActiveCallScreen else {
            return nil
        }

        let handle = voiceCoordinator.activeHandle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let contactName = (handle?.isEmpty == false ? handle! : "Interpreter Desk")
        let callUUID = voiceCoordinator.activeCallUUID?.uuidString ?? "preview"
        let now = ISO8601DateFormatter().string(from: Date())

        var debugCall = MobileCall(
            id: "debug-live-assist-\(callUUID)",
            callSid: "CA_DEBUG_\(callUUID)",
            contactId: nil,
            contactName: contactName,
            contactPhone: "+19493066291",
            lineId: bootstrap.ownerLine?.id,
            fromNumber: bootstrap.ownerLine?.phoneNumber ?? bootstrap.capabilities.defaultMainLine,
            toNumber: "+19493066291",
            status: "in-progress",
            durationSeconds: 64,
            screeningOutcome: nil,
            transferOutcome: nil,
            recordingUrl: nil,
            transcript: "Julia: Hi Olivia, I am calling on behalf of Jacob to coordinate a sign language interpreter for Innovation Expo.",
            summary: "Interpreter coordination call in progress.",
            agentId: "debug-agent",
            folderId: nil,
            transcriptStatus: "complete",
            summarySmsSentAt: nil,
            readAt: nil,
            intakePayload: [
                "call_mode": .string("agent_autonomous"),
                "last_status": .string("connected"),
                "line_owner_type": .string("agent"),
                "voice_agent_id": .string("debug-agent"),
            ],
            createdAt: now,
            updatedAt: now
        )
        debugCall.liveAssistEligible = true
        debugCall.executionMode = "agent_autonomous"
        return debugCall
    }
#endif
}

private struct RotaryMinimizedCallBanner: View {
    @Bindable var voiceCoordinator: VoiceCoordinator
    let observedCall: MobileCall?
    let glassNamespace: Namespace.ID
    let restore: () -> Void

    private var bannerTitle: String {
        voiceCoordinator.activeHandle ?? "Return to call"
    }

    private var bannerStatusTitle: String {
        observedCall?.liveStatusTitle ?? voiceCoordinator.callPresentationState.statusTitle
    }

    var body: some View {
        HStack(spacing: 14) {
            Button(action: restore) {
                HStack(spacing: 12) {
                    RotaryCallAvatarBadge(
                        title: bannerTitle,
                        size: 44,
                        namespace: glassNamespace
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Return to call")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text("\(bannerTitle) • \(bannerStatusTitle)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
                .buttonStyle(.plain)

            Spacer(minLength: 10)

            RotaryGlassIconButton(
                systemName: voiceCoordinator.isMuted ? "mic.slash.fill" : "mic.fill",
                size: 15,
                frameSize: 40,
                shape: .circle
            ) {
                voiceCoordinator.toggleMute()
            }
            .disabled(!voiceCoordinator.supportsInAppCallControls || voiceCoordinator.isEndingCall)
            .opacity((voiceCoordinator.supportsInAppCallControls && !voiceCoordinator.isEndingCall) ? 1 : 0.54)

            Button {
                voiceCoordinator.endCurrentCall()
            } label: {
                ZStack {
                    Circle()
                        .fill(RotaryTheme.destructive)
                        .frame(width: 40, height: 40)
                    Image(systemName: voiceCoordinator.isEndingCall ? "hourglass" : "phone.down.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .disabled(voiceCoordinator.isEndingCall)
            .opacity(voiceCoordinator.isEndingCall ? 0.7 : 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(bannerBackground)
        .overlay(bannerStroke)
        .shadow(color: RotaryTheme.shadow.opacity(0.18), radius: 18, x: 0, y: 10)
        .accessibilityIdentifier("rotary.minimizedCallBanner")
    }

    @ViewBuilder
    private var bannerBackground: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.clear)
                .glassEffect(
                    .regular.tint(Color.white.opacity(0.14)).interactive(false),
                    in: .rect(cornerRadius: 26)
                )
        } else {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.regularMaterial)
        }
    }

    private var bannerStroke: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
    }
}

private struct RotaryActiveCallScreen: View {
    @Bindable var voiceCoordinator: VoiceCoordinator
    let activeLiveAssistCall: MobileCall?
    let api: RotaryAPIClient
    let tokenProvider: RotaryTokenProvider
    let glassNamespace: Namespace.ID
    let dismiss: () -> Void

    @State private var keypadEntry = ""
    @State private var showingKeypad = false
    @State private var showingAudioRoutes = false
    @State private var liveAssistSheetCall: MobileCall?

    private var controlsEnabled: Bool {
        voiceCoordinator.supportsInAppCallControls &&
            voiceCoordinator.callPresentationState != .requestingCallKit &&
            voiceCoordinator.callPresentationState != .startedConnecting &&
            !voiceCoordinator.isEndingCall
    }

    private var liveAssistVisible: Bool {
        activeLiveAssistCall?.shouldShowLiveSteerControls == true
    }

    private var callStatusTitle: String {
        activeLiveAssistCall?.liveStatusTitle ?? voiceCoordinator.callPresentationState.statusTitle
    }

    private var callStatusTint: Color {
        switch voiceCoordinator.callPresentationState {
        case .ringing, .requestingCallKit, .startedConnecting:
            return RotaryTheme.warning
        case .connected:
            return RotaryTheme.callAccent
        case .ended, .failed:
            return RotaryTheme.destructive
        case .idle:
            return RotaryTheme.accent
        }
    }

    private var heroSubtitle: String {
        let lastAction = voiceCoordinator.lastActionMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let lastAction, !lastAction.isEmpty {
            return lastAction
        }

        let remote = voiceCoordinator.activeRemoteAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let remote, !remote.isEmpty {
            return remote
        }

        if !liveAssistVisible {
            return RotaryLanguageCopy.text(
                "Rotary is keeping this live call stable while you stay in control.",
                "Rotary가 통화를 안정적으로 유지하고 있어요. 계속 제어할 수 있습니다."
            )
        }

        return RotaryLanguageCopy.text(
            "Rotary is keeping the call transcribed and ready for live steering.",
            "Rotary가 통화를 실시간으로 기록하고, 실시간 조종에 준비되어 있어요."
        )
    }

    private var audioControlTitle: String {
        RotaryLanguageCopy.text("Speaker", "스피커")
    }

    private var audioControlAction: () -> Void {
        {
            if voiceCoordinator.availableAudioRoutes.count > 2 {
                showingAudioRoutes = true
            } else {
                voiceCoordinator.toggleSpeaker()
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RotaryBackdrop()
                GeometryReader { proxy in
                    let compact = proxy.size.height <= 760
                    activeCallLayout(compact: compact)
                }
            }
            .sheet(isPresented: $showingKeypad) {
                RotaryDialpadSheet(
                    keypadEntry: $keypadEntry,
                    controlsEnabled: controlsEnabled,
                    sendDigit: { digit in
                        keypadEntry.append(digit)
                        voiceCoordinator.sendDTMFDigits(digit)
                    }
                )
            }
            .confirmationDialog("Audio Output", isPresented: $showingAudioRoutes, titleVisibility: .visible) {
                ForEach(voiceCoordinator.availableAudioRoutes) { route in
                    Button(route.output.title) {
                        voiceCoordinator.selectAudioRoute(route.output)
                    }
                }
            }
            .sheet(item: $liveAssistSheetCall) { call in
                LiveAssistSheet(
                    call: call,
                    api: api,
                    voiceCoordinator: voiceCoordinator,
                    tokenProvider: tokenProvider
                )
            }
            .onChange(of: voiceCoordinator.debugLiveAssistSheetRequestID) { _, _ in
                guard let activeLiveAssistCall else {
                    voiceCoordinator.lastActionMessage = "Live assist opens after Rotary links a live call record."
                    return
                }
                liveAssistSheetCall = activeLiveAssistCall
            }
            .onChange(of: voiceCoordinator.debugShowKeypadRequestID) { _, _ in
                showingKeypad = true
            }
            .onChange(of: voiceCoordinator.debugHideKeypadRequestID) { _, _ in
                showingKeypad = false
            }
        }
    }

    private func activeCallContent(compact: Bool) -> some View {
        VStack(spacing: compact ? 14 : 16) {
            callHeader(compact: compact)
            controlsGridSurface(compact: compact)
        }
    }

    private func callHeader(compact: Bool) -> some View {
        VStack(spacing: compact ? 12 : 14) {
            RotaryCallAvatarBadge(
                title: voiceCoordinator.activeHandle ?? "Rotary call",
                size: compact ? 84 : 108,
                namespace: glassNamespace
            )

            Text(voiceCoordinator.activeHandle ?? "Rotary call")
                .font(.system(size: compact ? 27 : 36, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            RotaryCallStatusChip(title: callStatusTitle, tint: callStatusTint)

            Text(heroSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(compact ? 2 : 3)
        }
        .frame(maxWidth: .infinity)
    }

    private func controlsGridSurface(compact: Bool) -> some View {
        let spacing: CGFloat = compact ? 14 : 16
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3)

        return Group {
            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: spacing) {
                    LazyVGrid(columns: columns, spacing: spacing) {
                        callControlTiles
                    }
                }
            } else {
                LazyVGrid(columns: columns, spacing: spacing) {
                    callControlTiles
                }
            }
        }
        .padding(.horizontal, compact ? 6 : 12)
    }

    @ViewBuilder
    private var callControlTiles: some View {
        RotaryCallActionTile(
            title: voiceCoordinator.isMuted
                ? RotaryLanguageCopy.text("Unmute", "음소거 해제")
                : RotaryLanguageCopy.text("Mute", "음소거"),
            systemImage: voiceCoordinator.isMuted ? "mic.slash.fill" : "mic.fill",
            active: voiceCoordinator.isMuted,
            tint: RotaryTheme.destructive,
            enabled: controlsEnabled,
            action: { voiceCoordinator.toggleMute() }
        )

        RotaryCallActionTile(
            title: audioControlTitle,
            systemImage: "speaker.wave.2.fill",
            active: voiceCoordinator.isSpeakerEnabled,
            tint: RotaryTheme.callAccent,
            enabled: controlsEnabled,
            action: audioControlAction
        )

        RotaryCallActionTile(
            title: RotaryLanguageCopy.text("Keypad", "키패드"),
            systemImage: "circle.grid.3x3.fill",
            active: showingKeypad,
            tint: RotaryTheme.accent,
            enabled: controlsEnabled,
            action: { showingKeypad = true }
        )

        RotaryCallActionTile(
            title: voiceCoordinator.isCallOnHold
                ? RotaryLanguageCopy.text("Resume", "재개")
                : RotaryLanguageCopy.text("Hold", "보류"),
            systemImage: voiceCoordinator.isCallOnHold ? "play.fill" : "pause.fill",
            active: voiceCoordinator.isCallOnHold,
            tint: RotaryTheme.warning,
            enabled: controlsEnabled,
            action: { voiceCoordinator.toggleHold() }
        )

        RotaryCallActionTile(
            title: RotaryLanguageCopy.text("Conference", "회의"),
            systemImage: "person.3.fill",
            active: activeLiveAssistCall != nil,
            tint: RotaryTheme.callAccent,
            enabled: true,
            action: {
                if let activeLiveAssistCall {
                    liveAssistSheetCall = activeLiveAssistCall
                } else {
                    voiceCoordinator.lastActionMessage = RotaryLanguageCopy.text(
                        "Conference add/remove unlocks once Rotary matches this live call.",
                        "Rotary가 라이브 통화를 연결하면 회의 참가자 추가/제거가 활성화됩니다."
                    )
                }
            }
        )

        RotaryCallActionTile(
            title: RotaryLanguageCopy.text("Transcript", "대화록"),
            systemImage: "text.bubble.fill",
            active: liveAssistVisible,
            tint: RotaryTheme.accent,
            enabled: true,
            action: {
                if let activeLiveAssistCall {
                    liveAssistSheetCall = activeLiveAssistCall
                } else {
                    voiceCoordinator.lastActionMessage = "Live transcript opens after Rotary links this call."
                }
            }
        )
    }

    @ViewBuilder
    private func activeCallLayout(compact: Bool) -> some View {
        let topPadding: CGFloat = compact ? 8 : 16
        let bottomPadding: CGFloat = compact ? 10 : 22

        VStack(spacing: 0) {
            activeCallContent(compact: compact)
                .padding(.horizontal, 20)
                .padding(.top, topPadding)

            Spacer(minLength: compact ? 4 : 10)

            endCallButton(compact: compact)
                .padding(.horizontal, 20)
                .padding(.bottom, bottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    RotaryGlassIcon(systemName: "chevron.down", size: 14, frameSize: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(RotaryLanguageCopy.text("Minimize call", "통화 최소화"))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
    }

    private func endCallButton(compact: Bool) -> some View {
        Button {
            voiceCoordinator.endCurrentCall()
        } label: {
            HStack(spacing: 12) {
                if voiceCoordinator.isEndingCall {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: compact ? 18 : 19, weight: .semibold))
                }

                Text(
                    RotaryLanguageCopy.text(
                        voiceCoordinator.isEndingCall ? "Ending call" : "End call",
                        voiceCoordinator.isEndingCall ? "통화 종료 중" : "통화 종료"
                    )
                )
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 16 : 18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(RotaryTheme.destructive)
            )
            .shadow(color: RotaryTheme.destructive.opacity(0.25), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(voiceCoordinator.isEndingCall)
        .opacity(voiceCoordinator.isEndingCall ? 0.7 : 1)
    }
}

private struct RotaryDialpadSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var keypadEntry: String
    let controlsEnabled: Bool
    let sendDigit: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                RotaryBackdrop()

                VStack(spacing: 16) {
                    RotaryGlassCard {
                        HStack {
                            Color.clear
                                .frame(width: 1, height: 1)
                            Spacer()
                            if !keypadEntry.isEmpty {
                                Button("Clear") {
                                    keypadEntry = ""
                                }
                                .font(.footnote.weight(.semibold))
                            }
                        }

                        Text(keypadEntry.isEmpty ? "Tap digits to navigate menus." : keypadEntry)
                            .font(.system(.title3, design: .monospaced).weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(keypadEntry.isEmpty ? .secondary : .primary)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
                        ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"], id: \.self) { digit in
                            Button {
                                sendDigit(digit)
                            } label: {
                                Text(digit)
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(
                                        RotaryTheme.elevatedSurface,
                                        in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(!controlsEnabled)
                            .opacity(controlsEnabled ? 1 : 0.54)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        RotaryGlassIcon(systemName: "chevron.left", size: 14, frameSize: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }
            }
        }
    }
}

private struct ActiveCallLiveAssistPanel: View {
    let call: MobileCall?
    let api: RotaryAPIClient
    @Bindable var voiceCoordinator: VoiceCoordinator
    let tokenProvider: RotaryTokenProvider
    let compact: Bool
    let openDetails: () -> Void

    @State private var liveAssist: MobileLiveAssistResponse?
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var customInstruction = ""
    @State private var steerMode: LiveSteerMode = .steer
    @State private var queuedUtterance: String?
    @State private var isWorking = false
    @State private var autoRecommendationTask: Task<Void, Never>?
    @State private var autoRecommendationToken: String?
    @State private var autoRecommendationCountdown = 0

    private var warmTranscript: String {
        if let call {
            let callContext = [call.summary, call.transcript]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty })
            if let callContext {
                return callContext
            }
        }

        if let lastActionMessage = voiceCoordinator.lastActionMessage,
           !lastActionMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return lastActionMessage
        }

        switch voiceCoordinator.callPresentationState {
        case .requestingCallKit:
            return "Rotary is opening the call and preparing the live transcript."
        case .startedConnecting:
            return "Rotary is dialing and warming the steering controls in the background."
        case .ringing:
            return "The far side is still ringing. Rotary is standing by to unlock steer the moment the call record lands."
        case .connected:
            return "Rotary is connected and syncing the live transcript."
        case .ended:
            return "This call has ended."
        case .idle, .failed:
            return "Rotary will surface live steer here as soon as the next call starts."
        }
    }

    private var warmSuggestedNext: String {
        if call == nil {
            return "Steer, join, and listen become available as soon as Rotary matches the live call."
        }
        return "Rotary is fetching live steering in the background. You can keep talking while this catches up."
    }

    private var fallbackSteeringOptions: [String] {
        [
            "Ask a clarifying question.",
            "Summarize the last point.",
            "Confirm the caller's preferred next step.",
        ]
    }

    private var steeringOptions: [String] {
        let options = (liveAssist?.steeringOptions ?? fallbackSteeringOptions)
            .compactMap(normalizedText)
        return options.isEmpty ? fallbackSteeringOptions : options
    }

    private var recommendedOption: String? {
        steeringOptions.first
    }

    private var queuedPreview: String {
        if let queuedUtterance {
            return queuedUtterance
        }
        if let suggested = normalizedText(liveAssist?.suggestedNext) {
            return suggested
        }
        return warmSuggestedNext
    }

    var body: some View {
        RotaryCallPanel(alignment: .leading, spacing: compact ? 10 : 12, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: compact ? 10 : 12) {
                HStack(spacing: 8) {
                    panelActionIcon(
                        systemImage: "ear.fill",
                        enabled: call != nil,
                        action: { Task { await control(action: "listen_only") } }
                    )
                    panelActionIcon(
                        systemImage: "person.wave.2.fill",
                        enabled: call != nil,
                        action: { Task { await control(action: "join") } }
                    )
                    panelActionIcon(
                        systemImage: "figure.stand",
                        enabled: call != nil,
                        action: { Task { await control(action: "take_over") } }
                    )

                    Spacer(minLength: 0)

                    panelActionIcon(
                        systemImage: "arrow.up.left.and.arrow.down.right",
                        enabled: call != nil,
                        action: {
                            if call != nil {
                                openDetails()
                            }
                        }
                    )
                }

                Text(liveAssist == nil ? warmTranscript : (liveAssist?.transcript.isEmpty == false ? liveAssist?.transcript ?? "" : liveAssist?.intentSummary ?? ""))
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                    .lineLimit(compact ? 4 : 5)

                suggestionTabs

                composerDock

                if let actionMessage, !actionMessage.isEmpty {
                    Text(actionMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .task(id: call?.id ?? "pending-live-assist") {
            guard let call else {
                liveAssist = nil
                errorMessage = nil
                actionMessage = nil
                cancelAutoRecommendation(resetToken: true)
                return
            }

            await reload(for: call)
            while !Task.isCancelled && voiceCoordinator.callPresentationState.presentsActiveCallScreen {
                try? await Task.sleep(for: .seconds(2))
                await reload(for: call)
            }
        }
        .onChange(of: customInstruction) { _, value in
            if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cancelAutoRecommendation()
            }
        }
        .onChange(of: steerMode) { _, _ in
            guard let call else { return }
            scheduleAutoRecommendationIfNeeded(for: call)
        }
        .onChange(of: voiceCoordinator.debugSteerRequestID) { _, _ in
            applyDebugSteerRequest()
        }
        .onDisappear {
            cancelAutoRecommendation(resetToken: true)
        }
    }

    private var suggestionTabs: some View {
        HStack(spacing: 8) {
            ForEach(Array(steeringOptions.prefix(3).enumerated()), id: \.offset) { index, option in
                Button {
                    Task { await steer(selectedOption: option, customText: nil, source: .manual) }
                } label: {
                    HStack(spacing: 6) {
                        if index == 0 {
                            Image(systemName: "sparkles")
                                .font(.caption2.weight(.bold))
                        }
                        Text(option)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(
                        (index == 0 ? RotaryTheme.callAccent.opacity(0.16) : RotaryTheme.softSurface),
                        in: Capsule(style: .continuous)
                    )
                    .foregroundStyle(index == 0 ? RotaryTheme.callAccent : .primary)
                }
                .buttonStyle(.plain)
                .disabled(isWorking || call == nil)
                .opacity((isWorking || call == nil) ? 0.56 : 1)
            }
        }
    }

    private var composerDock: some View {
        HStack(spacing: 8) {
            modeIcon(mode: .interrupt, systemImage: "bolt.fill", accessibilityLabel: "Interrupt mode")
            modeIcon(mode: .steer, systemImage: "arrowshape.turn.up.right.fill", accessibilityLabel: "Steer mode")

            TextField(RotaryLanguageCopy.text("Whisper to agent", "에이전트에게 속삭이기"), text: $customInstruction, axis: .vertical)
                .lineLimit(1 ... 3)
                .rotaryTextFieldStyle()

            Button {
                Task { await steer(selectedOption: nil, customText: customInstruction, source: .manual) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        customInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? .secondary
                            : RotaryTheme.callAccent
                    )
            }
            .buttonStyle(.plain)
            .disabled(isWorking || customInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func modeIcon(mode: LiveSteerMode, systemImage: String, accessibilityLabel: String) -> some View {
        Button {
            steerMode = mode
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(mode == steerMode ? RotaryTheme.callAccent : .secondary)
                .frame(width: 30, height: 30)
                .background(
                    mode == steerMode ? RotaryTheme.callAccent.opacity(0.14) : RotaryTheme.softSurface,
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func panelActionIcon(
        systemImage: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(
                    RotaryTheme.softSurface,
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .disabled(isWorking || !enabled)
        .opacity((isWorking || !enabled) ? 0.56 : 1)
    }

    private func reload(for call: MobileCall) async {
        do {
            liveAssist = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.liveAssist(token: token, callId: call.id)
            }
            errorMessage = nil
            scheduleAutoRecommendationIfNeeded(for: call)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func steer(selectedOption: String?, customText: String?, source: LiveSteerSource) async {
        guard let call else {
            errorMessage = "Live steer is still preparing."
            return
        }

        guard let payload = steerPayload(selectedOption: selectedOption, customText: customText) else {
            errorMessage = "Add a valid instruction before steering."
            return
        }

        cancelAutoRecommendation(resetToken: source == .manual)
        isWorking = true
        defer { isWorking = false }

        do {
            let result = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.steerCall(
                    token: token,
                    callId: call.id,
                    selectedOption: payload.selectedOption,
                    customText: payload.customText
                )
            }
            if selectedOption == nil {
                customInstruction = ""
            }
            queuedUtterance = payload.queuedPreview
            actionMessage = source == .automatic
                ? "Auto-applied recommended: \(result.applied)"
                : "Applied (\(steerMode.title.lowercased())): \(result.applied)"
            await reload(for: call)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func control(action: String) async {
        guard let call else {
            errorMessage = "Live steer is still preparing."
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            let result = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.controlCall(token: token, callId: call.id, action: action)
            }
            if let joinContext = result.joinContext {
                voiceCoordinator.rememberJoinContext(joinContext)
                if action == "join" || action == "listen_only" || action == "take_over" {
                    try await voiceCoordinator.startLiveAssistJoin(call: call, context: joinContext)
                    let mode = joinContext.callMode.replacingOccurrences(of: "_", with: " ")
                    actionMessage = "Prepared \(mode). Joining the call from Rotary."
                } else {
                    let mode = joinContext.callMode.replacingOccurrences(of: "_", with: " ")
                    actionMessage = "Prepared \(mode)."
                }
            } else {
                if action == "leave" || action == "resume_agent" || action == "end_call" {
                    voiceCoordinator.endCurrentCall()
                }
                actionMessage = "\(result.action.replacingOccurrences(of: "_", with: " ").capitalized) applied."
            }
            await reload(for: call)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func steerPayload(selectedOption: String?, customText: String?) -> (selectedOption: String?, customText: String?, queuedPreview: String)? {
        if let option = normalizedText(selectedOption) {
            switch steerMode {
            case .steer:
                return (selectedOption: option, customText: nil, queuedPreview: option)
            case .interrupt:
                let interruptText = "Interrupt now and prioritize this line: \(option)"
                return (selectedOption: nil, customText: interruptText, queuedPreview: option)
            }
        }

        guard let custom = normalizedText(customText) else {
            return nil
        }

        switch steerMode {
        case .interrupt:
            return (
                selectedOption: nil,
                customText: "Interrupt now and say: \(custom)",
                queuedPreview: custom
            )
        case .steer:
            return (selectedOption: nil, customText: custom, queuedPreview: custom)
        }
    }

    private func scheduleAutoRecommendationIfNeeded(for call: MobileCall) {
        guard steerMode.shouldAutoApplyRecommended,
              customInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !isWorking,
              let recommendation = recommendedOption else {
            cancelAutoRecommendation()
            return
        }

        let token = "\(call.id)|\(recommendation)|\(steerMode.rawValue)"
        guard token != autoRecommendationToken else { return }

        cancelAutoRecommendation()
        autoRecommendationToken = token
        autoRecommendationCountdown = 4

        autoRecommendationTask = Task {
            for remaining in stride(from: 3, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                autoRecommendationCountdown = remaining
            }
            guard !Task.isCancelled else { return }
            await steer(selectedOption: recommendation, customText: nil, source: .automatic)
        }
    }

    private func cancelAutoRecommendation(resetToken: Bool = false) {
        autoRecommendationTask?.cancel()
        autoRecommendationTask = nil
        autoRecommendationCountdown = 0
        if resetToken {
            autoRecommendationToken = nil
        }
    }

    private func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func applyDebugSteerRequest() {
        guard let modeRawValue = normalizedText(voiceCoordinator.debugSteerMode) else {
            return
        }
        let requestedMode = modeRawValue == "queue" ? LiveSteerMode.steer : LiveSteerMode(rawValue: modeRawValue)
        guard let requestedMode else { return }
        steerMode = requestedMode

        guard let recommendation = recommendedOption else {
            errorMessage = "No steering recommendation is available yet."
            return
        }

        Task {
            await steer(selectedOption: recommendation, customText: nil, source: .manual)
        }
    }

    private enum LiveSteerSource {
        case manual
        case automatic
    }
}

private struct LiveAssistSheet: View {
    @Environment(\.dismiss) private var dismiss

    let call: MobileCall
    let api: RotaryAPIClient
    @Bindable var voiceCoordinator: VoiceCoordinator
    let tokenProvider: RotaryTokenProvider

    @State private var liveAssist: MobileLiveAssistResponse?
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var customInstruction = ""
    @State private var steerMode: LiveSteerMode = .steer
    @State private var queuedUtterance: String?
    @State private var isWorking = false
    @State private var autoRecommendationTask: Task<Void, Never>?
    @State private var autoRecommendationToken: String?
    @State private var autoRecommendationCountdown = 0
    @State private var suggestionDetail: LiveAssistSuggestionDetail?

    private var warmLiveAssistSummary: String {
        let candidates = [call.summary, call.transcript, voiceCoordinator.lastActionMessage]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        return candidates.first(where: { !$0.isEmpty })
            ?? RotaryLanguageCopy.text(
                "Rotary is syncing the live transcript and steering options in the background.",
                "Rotary가 실시간 대화록과 조종 옵션을 백그라운드에서 동기화하고 있어요."
            )
    }

    private var fallbackSteeringOptions: [String] {
        [
            RotaryLanguageCopy.text("Ask a clarifying question.", "확인 질문을 해 주세요."),
            RotaryLanguageCopy.text("Summarize the last point.", "방금 내용을 요약해 주세요."),
            RotaryLanguageCopy.text("Confirm the caller's preferred next step.", "상대가 원하는 다음 단계를 확인해 주세요."),
        ]
    }

    private var steeringOptions: [String] {
        let options = (liveAssist?.steeringOptions ?? fallbackSteeringOptions)
            .compactMap(normalizedText)
        return options.isEmpty ? fallbackSteeringOptions : options
    }

    private var recommendedOption: String? {
        steeringOptions.first
    }

    private var queuedPreview: String {
        if let queuedUtterance {
            return queuedUtterance
        }
        if let suggested = normalizedText(liveAssist?.suggestedNext) {
            return suggested
        }
        return RotaryLanguageCopy.text("Rotary will suggest the next line here.", "Rotary가 다음 문장을 여기에서 제안해요.")
    }

    private var transcriptPreview: String {
        if let liveAssist, !liveAssist.transcript.isEmpty {
            return liveAssist.transcript
        }
        return warmLiveAssistSummary
    }

    private var transcriptLines: [LiveAssistTranscriptLine] {
        let source = transcriptPreview
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !source.isEmpty else {
            return [LiveAssistTranscriptLine(id: 0, speaker: nil, message: warmLiveAssistSummary, fromAgent: true)]
        }

        return source.enumerated().map { index, line in
            if let separator = line.firstIndex(of: ":") {
                let speaker = String(line[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
                let message = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedSpeaker = speaker.lowercased()
                let fromAgent = normalizedSpeaker.contains("agent")
                    || normalizedSpeaker.contains("rotary")
                    || normalizedSpeaker.contains("julia")
                    || normalizedSpeaker.contains("assistant")
                return LiveAssistTranscriptLine(
                    id: index,
                    speaker: speaker.isEmpty ? nil : speaker,
                    message: message.isEmpty ? line : message,
                    fromAgent: fromAgent
                )
            }

            return LiveAssistTranscriptLine(id: index, speaker: nil, message: line, fromAgent: true)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RotaryBackdrop()
                transcriptScrollContent
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                steeringDock
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button(RotaryLanguageCopy.text("Join", "참여"), systemImage: "phone.arrow.up.right") {
                            Task { await control(action: "join") }
                        }
                        Button(RotaryLanguageCopy.text("Listen", "듣기"), systemImage: "ear") {
                            Task { await control(action: "listen_only") }
                        }
                        Button(RotaryLanguageCopy.text("Take Over", "직접 개입"), systemImage: "hand.raised.fill") {
                            Task { await control(action: "take_over") }
                        }
                        Button(RotaryLanguageCopy.text("Resume Agent", "에이전트 재개"), systemImage: "arrow.trianglehead.clockwise") {
                            Task { await control(action: "resume_agent") }
                        }
                        Button(RotaryLanguageCopy.text("Leave", "나가기"), systemImage: "arrow.uturn.backward.circle") {
                            Task { await control(action: "leave") }
                        }
                        Divider()
                        Button(RotaryLanguageCopy.text("End Call", "통화 종료"), systemImage: "phone.down.fill", role: .destructive) {
                            Task { await control(action: "end_call") }
                        }
                    } label: {
                        RotaryGlassIcon(systemName: "slider.horizontal.3", size: 13, frameSize: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(RotaryLanguageCopy.text("Call actions", "통화 작업"))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        RotaryGlassIcon(systemName: "xmark", size: 12, frameSize: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(RotaryLanguageCopy.text("Close live assist", "라이브 어시스트 닫기"))
                }
            }
            .sheet(item: $suggestionDetail) { detail in
                NavigationStack {
                    ZStack {
                        RotaryBackdrop()
                        ScrollView {
                            Text(detail.text)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(20)
                        }
                    }
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                suggestionDetail = nil
                            } label: {
                                RotaryGlassIcon(systemName: "xmark", size: 12, frameSize: 34)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .task(id: call.id) {
                await reload()
                while !Task.isCancelled && voiceCoordinator.callPresentationState.presentsActiveCallScreen {
                    try? await Task.sleep(for: .seconds(2))
                    await reload()
                }
            }
            .onChange(of: customInstruction) { _, value in
                if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    cancelAutoRecommendation()
                }
            }
            .onChange(of: steerMode) { _, _ in
                scheduleAutoRecommendationIfNeeded()
            }
            .onChange(of: voiceCoordinator.debugSteerRequestID) { _, _ in
                applyDebugSteerRequest()
            }
            .onChange(of: voiceCoordinator.debugDismissLiveAssistSheetRequestID) { _, _ in
                dismiss()
            }
            .onChange(of: voiceCoordinator.callPresentationState) { _, state in
                if !state.presentsActiveCallScreen {
                    dismiss()
                }
            }
            .onDisappear {
                cancelAutoRecommendation(resetToken: true)
            }
        }
    }

    private var transcriptScrollContent: some View {
        ScrollViewReader { reader in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(transcriptLines) { line in
                        transcriptBubble(line)
                    }

                    if let actionMessage, !actionMessage.isEmpty {
                        Text(actionMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("transcript-bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.18)) {
                    reader.scrollTo("transcript-bottom", anchor: .bottom)
                }
            }
            .onChange(of: liveAssist?.transcript ?? "") { _, _ in
                withAnimation(.easeOut(duration: 0.18)) {
                    reader.scrollTo("transcript-bottom", anchor: .bottom)
                }
            }
        }
    }

    private var steeringDock: some View {
        VStack(spacing: 8) {
            suggestionList
            HStack {
                if let intentSummary = normalizedText(liveAssist?.intentSummary) {
                    Text(intentSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(queuedPreview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if steerMode.shouldAutoApplyRecommended, autoRecommendationCountdown > 0 {
                    RotaryPill(text: "Auto \(autoRecommendationCountdown)s", active: true)
                }
            }
            composerDock
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.clear)
    }

    private var suggestionList: some View {
        VStack(spacing: 6) {
            ForEach(Array(steeringOptions.prefix(3).enumerated()), id: \.offset) { index, option in
                HStack(spacing: 8) {
                    Button {
                        Task { await steer(selectedOption: option, customText: nil, source: .manual) }
                    } label: {
                        HStack(spacing: 8) {
                            if index == 0 {
                                Image(systemName: "sparkles")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(RotaryTheme.callAccent)
                            }
                            Text(option)
                                .font(.caption.weight(.semibold))
                                .lineLimit(2)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(
                            index == 0 ? RotaryTheme.callAccent.opacity(0.14) : RotaryTheme.softSurface,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .foregroundStyle(index == 0 ? RotaryTheme.callAccent : .primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                    .opacity(isWorking ? 0.56 : 1)

                    Button {
                        suggestionDetail = LiveAssistSuggestionDetail(text: option)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(
                                RotaryTheme.softSurface,
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var composerDock: some View {
        HStack(spacing: 8) {
            modeIcon(mode: .interrupt, systemImage: "bolt.fill", accessibilityLabel: "Interrupt mode")
            modeIcon(mode: .steer, systemImage: "arrowshape.turn.up.right.fill", accessibilityLabel: "Steer mode")

            TextField(RotaryLanguageCopy.text("Whisper to agent", "에이전트에게 속삭이기"), text: $customInstruction, axis: .vertical)
                .lineLimit(1 ... 3)
                .rotaryTextFieldStyle()

            Button {
                Task { await steer(selectedOption: nil, customText: customInstruction, source: .manual) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        customInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? .secondary
                            : RotaryTheme.callAccent
                    )
            }
            .buttonStyle(.plain)
            .disabled(isWorking || customInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func compactActionIcon(
        systemImage: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(
                    RotaryTheme.softSurface,
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .disabled(isWorking || !enabled)
        .opacity((isWorking || !enabled) ? 0.56 : 1)
    }

    private func controlButton(
        _ title: String,
        systemImage: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(destructive ? RotaryTheme.destructive : Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RotaryTheme.elevatedSurface,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .opacity(isWorking ? 0.56 : 1)
    }

    private func modeIcon(mode: LiveSteerMode, systemImage: String, accessibilityLabel: String) -> some View {
        Button {
            steerMode = mode
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(mode == steerMode ? RotaryTheme.callAccent : .secondary)
                .frame(width: 30, height: 30)
                .background(
                    mode == steerMode ? RotaryTheme.callAccent.opacity(0.14) : RotaryTheme.softSurface,
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func transcriptBubble(_ line: LiveAssistTranscriptLine) -> some View {
        HStack {
            if line.fromAgent {
                Spacer(minLength: 36)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let speaker = line.speaker {
                    Text(speaker)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(line.message)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                line.fromAgent ? RotaryTheme.callAccent.opacity(0.16) : RotaryTheme.softSurface,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(line.fromAgent ? RotaryTheme.callAccent.opacity(0.3) : RotaryTheme.elevatedStroke, lineWidth: 1)
            )

            if !line.fromAgent {
                Spacer(minLength: 36)
            }
        }
    }

    private func reload() async {
        do {
            liveAssist = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.liveAssist(token: token, callId: call.id)
            }
            errorMessage = nil
            scheduleAutoRecommendationIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func steer(selectedOption: String?, customText: String?, source: LiveSteerSource) async {
        guard let payload = steerPayload(selectedOption: selectedOption, customText: customText) else {
            errorMessage = "Add a valid instruction before steering."
            return
        }

        cancelAutoRecommendation(resetToken: source == .manual)
        isWorking = true
        defer { isWorking = false }

        do {
            let result = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.steerCall(
                    token: token,
                    callId: call.id,
                    selectedOption: payload.selectedOption,
                    customText: payload.customText
                )
            }
            if selectedOption == nil {
                customInstruction = ""
            }
            queuedUtterance = payload.queuedPreview
            actionMessage = source == .automatic
                ? "Auto-applied recommended: \(result.applied)"
                : "Applied (\(steerMode.title.lowercased())): \(result.applied)"
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func control(action: String) async {
        isWorking = true
        defer { isWorking = false }

        do {
            let result = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.controlCall(token: token, callId: call.id, action: action)
            }
            if let joinContext = result.joinContext {
                voiceCoordinator.rememberJoinContext(joinContext)
                if action == "join" || action == "listen_only" || action == "take_over" {
                    try await voiceCoordinator.startLiveAssistJoin(call: call, context: joinContext)
                    let mode = joinContext.callMode.replacingOccurrences(of: "_", with: " ")
                    actionMessage = "Prepared \(mode). Joining the call from Rotary."
                } else {
                    let mode = joinContext.callMode.replacingOccurrences(of: "_", with: " ")
                    actionMessage = "Prepared \(mode)."
                }
            } else {
                if action == "leave" || action == "resume_agent" || action == "end_call" {
                    voiceCoordinator.endCurrentCall()
                }
                actionMessage = "\(result.action.replacingOccurrences(of: "_", with: " ").capitalized) applied."
            }
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func steerPayload(selectedOption: String?, customText: String?) -> (selectedOption: String?, customText: String?, queuedPreview: String)? {
        if let option = normalizedText(selectedOption) {
            switch steerMode {
            case .steer:
                return (selectedOption: option, customText: nil, queuedPreview: option)
            case .interrupt:
                let interruptText = "Interrupt now and prioritize this line: \(option)"
                return (selectedOption: nil, customText: interruptText, queuedPreview: option)
            }
        }

        guard let custom = normalizedText(customText) else {
            return nil
        }

        switch steerMode {
        case .interrupt:
            return (
                selectedOption: nil,
                customText: "Interrupt now and say: \(custom)",
                queuedPreview: custom
            )
        case .steer:
            return (selectedOption: nil, customText: custom, queuedPreview: custom)
        }
    }

    private func scheduleAutoRecommendationIfNeeded() {
        guard steerMode.shouldAutoApplyRecommended,
              customInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !isWorking,
              let recommendation = recommendedOption else {
            cancelAutoRecommendation()
            return
        }

        let token = "\(call.id)|\(recommendation)|\(steerMode.rawValue)"
        guard token != autoRecommendationToken else { return }

        cancelAutoRecommendation()
        autoRecommendationToken = token
        autoRecommendationCountdown = 4

        autoRecommendationTask = Task {
            for remaining in stride(from: 3, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                autoRecommendationCountdown = remaining
            }
            guard !Task.isCancelled else { return }
            await steer(selectedOption: recommendation, customText: nil, source: .automatic)
        }
    }

    private func cancelAutoRecommendation(resetToken: Bool = false) {
        autoRecommendationTask?.cancel()
        autoRecommendationTask = nil
        autoRecommendationCountdown = 0
        if resetToken {
            autoRecommendationToken = nil
        }
    }

    private func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func applyDebugSteerRequest() {
        guard let modeRawValue = normalizedText(voiceCoordinator.debugSteerMode) else {
            return
        }
        let requestedMode = modeRawValue == "queue" ? LiveSteerMode.steer : LiveSteerMode(rawValue: modeRawValue)
        guard let requestedMode else { return }
        steerMode = requestedMode

        guard let recommendation = recommendedOption else {
            errorMessage = "No steering recommendation is available yet."
            return
        }

        Task {
            await steer(selectedOption: recommendation, customText: nil, source: .manual)
        }
    }

    private enum LiveSteerSource {
        case manual
        case automatic
    }

    private struct LiveAssistTranscriptLine: Identifiable {
        let id: Int
        let speaker: String?
        let message: String
        let fromAgent: Bool
    }

    private struct LiveAssistSuggestionDetail: Identifiable {
        let id = UUID()
        let text: String
    }
}
