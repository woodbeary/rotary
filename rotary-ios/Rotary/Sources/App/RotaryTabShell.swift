import SwiftUI

private struct RotaryCallAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
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
            return "Starting Call"
        case .startedConnecting:
            return "Calling"
        case .ringing:
            return "Ringing"
        case .connected:
            return "On Call"
        case .ended:
            return "Call Ended"
        case .idle:
            return "Phone"
        case .failed:
            return "Call Failed"
        }
    }
}

struct RotaryTabShell: View {
    @Binding var appearanceMode: RotaryAppearanceMode
    let appModel: AppModel
    let bootstrap: MobileBootstrapReadyState
    @Bindable var voiceCoordinator: VoiceCoordinator

    @State private var messagesStore: MessagesStore
    @State private var callsStore: CallsStore
    @State private var selectedTab = 0
    @State private var showingSettings = false
    @State private var liveAssistCall: MobileCall?
    @State private var callAlert: RotaryCallAlert?
    @State private var missedCallCount = 0
    @State private var unreadMessageCount = 0

    init(
        appearanceMode: Binding<RotaryAppearanceMode>,
        appModel: AppModel,
        bootstrap: MobileBootstrapReadyState,
        voiceCoordinator: VoiceCoordinator
    ) {
        _appearanceMode = appearanceMode
        self.appModel = appModel
        self.bootstrap = bootstrap
        self.voiceCoordinator = voiceCoordinator

        let tokenProvider: RotaryTokenProvider = { forceRefresh in
            try await appModel.token(forceRefresh: forceRefresh)
        }

        _messagesStore = State(initialValue: MessagesStore(
            bootstrap: bootstrap,
            api: appModel.apiClient,
            tokenProvider: tokenProvider
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

    var body: some View {
        let callPresentationState = voiceCoordinator.callPresentationState
        let isCallScreenPresented = voiceCoordinator.isCallScreenPresented
        let showsMinimizedCallBanner = callPresentationState.presentsActiveCallScreen && !isCallScreenPresented

        ZStack {
            TabView(selection: $selectedTab) {
                CallsScreen(
                    bootstrap: bootstrap,
                    store: callsStore,
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
                        liveAssistCall = call
                    },
                    onMissedCallCountChange: { missedCallCount = $0 }
                )
                .tabItem {
                    Label("Calls", systemImage: "phone.fill")
                }
                .badge(missedCallCount > 0 ? missedCallCount : 0)
                .tag(0)

                RotaryMessagesScreen(
                    bootstrap: bootstrap,
                    store: messagesStore,
                    startCall: { phoneNumber, fromNumber in
                        Task { await startManualCall(phoneNumber: phoneNumber, fromNumber: fromNumber) }
                    },
                    onUnreadCountChange: { unreadMessageCount = $0 }
                )
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
                .badge(unreadMessageCount > 0 ? unreadMessageCount : 0)
                .tag(1)

                AgentsScreen(
                    bootstrap: bootstrap,
                    appModel: appModel,
                    api: appModel.apiClient,
                    messagesStore: messagesStore,
                    callsStore: callsStore,
                    voiceCoordinator: voiceCoordinator,
                    refresh: { Task { await appModel.bootstrap(forceRefresh: true) } }
                )
                .tabItem {
                    Label("Agents", systemImage: "person.2.fill")
                }
                .tag(2)
            }
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(Color(uiColor: .systemBackground), for: .tabBar)
            .fullScreenCover(isPresented: $showingSettings) {
                SettingsSheet(
                    appearanceMode: $appearanceMode,
                    appModel: appModel,
                    bootstrap: bootstrap,
                    voiceCoordinator: voiceCoordinator
                )
            }
            .sheet(item: $liveAssistCall) { call in
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
                missedCallCount = callsStore.missedCallCount
                unreadMessageCount = messagesStore.unreadCount()
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
            .zIndex(0)

            if showsMinimizedCallBanner {
                VStack {
                    Spacer()
                    RotaryMinimizedCallBanner(
                        voiceCoordinator: voiceCoordinator,
                        observedCall: liveAssistCall
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
                    activeLiveAssistCall: liveAssistCall,
                    api: appModel.apiClient,
                    tokenProvider: tokenProvider,
                    dismiss: { voiceCoordinator.minimizeCallScreen() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .animation(.snappy(duration: 0.28, extraBounce: 0.05), value: isCallScreenPresented)
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
            liveAssistCall = nil
        }
        if case .failed = newValue {
            liveAssistCall = nil
        }
    }

    private func monitorObservedCall() async {
        guard voiceCoordinator.callPresentationState.presentsActiveCallScreen else {
            liveAssistCall = nil
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
            if liveAssistCall != nil {
                return
            }
        }
    }

    private func refreshObservedCall(forceRefresh: Bool) async {
        _ = await callsStore.loadCalls(forceRefresh: forceRefresh)
        let matchedCall = voiceCoordinator.matchingObservedCall(in: callsStore.allCalls)
        liveAssistCall = matchedCall
        voiceCoordinator.syncObservedCallRecord(matchedCall)
    }
}

private struct RotaryMinimizedCallBanner: View {
    @Bindable var voiceCoordinator: VoiceCoordinator
    let observedCall: MobileCall?
    let restore: () -> Void

    private var bannerTitle: String {
        voiceCoordinator.activeHandle ?? "Return to call"
    }

    private var bannerStatusTitle: String {
        observedCall?.liveStatusTitle ?? voiceCoordinator.callPresentationState.statusTitle
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: restore) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.18))
                            .frame(width: 42, height: 42)
                        Image(systemName: "phone.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.green)
                    }

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

            Spacer(minLength: 8)

            Button {
                voiceCoordinator.toggleMute()
            } label: {
                ZStack {
                    Circle()
                        .fill(RotaryTheme.softSurface)
                        .frame(width: 38, height: 38)
                    Image(systemName: voiceCoordinator.isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .buttonStyle(.plain)
            .disabled(!voiceCoordinator.supportsInAppCallControls || voiceCoordinator.isEndingCall)
            .opacity((voiceCoordinator.supportsInAppCallControls && !voiceCoordinator.isEndingCall) ? 1 : 0.54)

            Button {
                voiceCoordinator.endCurrentCall()
            } label: {
                ZStack {
                    Circle()
                        .fill(RotaryTheme.destructive)
                        .frame(width: 38, height: 38)
                    Image(systemName: voiceCoordinator.isEndingCall ? "hourglass" : "phone.down.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2))
        }
        .shadow(color: Color.black.opacity(0.08), radius: 18, y: 10)
        .accessibilityIdentifier("rotary.minimizedCallBanner")
    }
}

private struct RotaryActiveCallScreen: View {
    @Bindable var voiceCoordinator: VoiceCoordinator
    let activeLiveAssistCall: MobileCall?
    let api: RotaryAPIClient
    let tokenProvider: RotaryTokenProvider
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

    private var callStatusTitle: String {
        activeLiveAssistCall?.liveStatusTitle ?? voiceCoordinator.callPresentationState.statusTitle
    }

    private var audioControlTitle: String {
        "Audio"
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
            ZStack(alignment: .bottomTrailing) {
                RotaryBackdrop()
                GeometryReader { proxy in
                    ViewThatFits(in: .vertical) {
                        activeCallLayout(compact: false, availableHeight: proxy.size.height)
                        activeCallLayout(compact: true, availableHeight: proxy.size.height)
                    }
                }

                RotaryFloatingActionButton(
                    systemName: "circle.grid.3x3.fill",
                    tint: RotaryTheme.callAccent,
                    action: {
                        showingKeypad = true
                    }
                )
                .accessibilityLabel("Keypad")
                .accessibilityIdentifier("rotary.callKeypadButton")
                .padding(.trailing, 18)
                .padding(.bottom, 132)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func activeCallLayout(compact: Bool, availableHeight: CGFloat) -> some View {
        let sectionSpacing: CGFloat = compact ? 12 : 16
        let avatarSize: CGFloat = compact ? 76 : 92
        let titleSize: CGFloat = compact ? 28 : 32
        let topPadding: CGFloat = compact ? 10 : 18
        let bottomPadding: CGFloat = compact ? 18 : 24

        return VStack(spacing: sectionSpacing) {
            RotaryGlassCard {
                VStack(spacing: compact ? 12 : 16) {
                    RotaryAvatarView(
                        title: voiceCoordinator.activeHandle ?? "Rotary call",
                        size: avatarSize
                    )

                    VStack(spacing: 6) {
                        Text(voiceCoordinator.activeHandle ?? "Rotary call")
                            .font(.system(size: titleSize, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)

                        Text(callStatusTitle)
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        if let lastActionMessage = voiceCoordinator.lastActionMessage,
                           !lastActionMessage.isEmpty {
                            Text(lastActionMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(compact ? 2 : 3)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            RotaryGlassCard {
                VStack(spacing: compact ? 10 : 12) {
                    HStack {
                        Text("Call controls")
                            .font(.headline)
                        Spacer()
                        if !controlsEnabled {
                            Text("Waiting for audio")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: compact ? 16 : 22) {
                        callControlButton(
                            title: voiceCoordinator.isMuted ? "Unmute" : "Mute",
                            systemImage: voiceCoordinator.isMuted ? "mic.slash.fill" : "mic.fill",
                            active: voiceCoordinator.isMuted,
                            enabled: controlsEnabled,
                            action: { voiceCoordinator.toggleMute() }
                        )
                        callControlButton(
                            title: audioControlTitle,
                            systemImage: voiceCoordinator.currentAudioOutput.systemImage,
                            active: voiceCoordinator.isSpeakerEnabled,
                            enabled: controlsEnabled,
                            action: audioControlAction
                        )
                    }

                    HStack(spacing: compact ? 16 : 22) {
                        callControlButton(
                            title: voiceCoordinator.isCallOnHold ? "Resume" : "Hold",
                            systemImage: voiceCoordinator.isCallOnHold ? "play.fill" : "pause.fill",
                            active: voiceCoordinator.isCallOnHold,
                            enabled: controlsEnabled,
                            action: { voiceCoordinator.toggleHold() }
                        )
                        callControlButton(
                            title: "Live steer",
                            systemImage: "text.bubble.fill",
                            active: activeLiveAssistCall != nil,
                            enabled: true,
                            action: {
                                if let activeLiveAssistCall {
                                    liveAssistSheetCall = activeLiveAssistCall
                                } else {
                                    voiceCoordinator.lastActionMessage = "Matching the live call so steer, join, and listen unlock right away."
                                }
                            }
                        )
                        callControlButton(
                            title: "Minimize",
                            systemImage: "chevron.down",
                            active: false,
                            enabled: true,
                            action: dismiss
                        )
                    }
                }
            }

            ActiveCallLiveAssistPanel(
                call: activeLiveAssistCall,
                api: api,
                voiceCoordinator: voiceCoordinator,
                tokenProvider: tokenProvider,
                compact: compact,
                openDetails: {
                    if let activeLiveAssistCall {
                        liveAssistSheetCall = activeLiveAssistCall
                    }
                }
            )

            Spacer(minLength: compact ? 0 : 8)

            Button {
                voiceCoordinator.endCurrentCall()
            } label: {
                HStack(spacing: 10) {
                    if voiceCoordinator.isEndingCall {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image(systemName: "phone.down.fill")
                    }
                    Text(voiceCoordinator.isEndingCall ? "Ending call" : "End call")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? 16 : 18)
                .background(RotaryTheme.destructive, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(voiceCoordinator.isEndingCall)
            .opacity(voiceCoordinator.isEndingCall ? 0.7 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func callControlButton(
        title: String,
        systemImage: String,
        active: Bool = false,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(active ? RotaryTheme.accent.opacity(0.18) : RotaryTheme.elevatedSurface)
                        .frame(width: 72, height: 72)
                    Image(systemName: systemImage)
                        .font(.system(size: 24, weight: .semibold))
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(active ? RotaryTheme.accent : Color.primary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.54)
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
                            Text("Keypad")
                                .font(.headline)
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
            .navigationTitle("Keypad")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
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
    @State private var isWorking = false

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

    var body: some View {
        RotaryGlassCard {
            VStack(alignment: .leading, spacing: compact ? 10 : 12) {
                HStack {
                    Text("Live steer")
                        .font(.headline)
                    Spacer()
                    Button("Full view") {
                        if call != nil {
                            openDetails()
                        }
                    }
                    .font(.footnote.weight(.semibold))
                    .disabled(call == nil)
                    .opacity(call == nil ? 0.54 : 1)
                }

                if let liveAssist {
                    VStack(alignment: .leading, spacing: compact ? 8 : 10) {
                        Text(liveAssist.transcript.isEmpty ? liveAssist.intentSummary : liveAssist.transcript)
                            .foregroundStyle(.secondary)
                            .lineLimit(compact ? 3 : 4)

                        Text(liveAssist.suggestedNext)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            ForEach(Array(liveAssist.steeringOptions.prefix(2).enumerated()), id: \.offset) { index, option in
                                Button {
                                    Task { await steer(selectedOption: option, customText: nil) }
                                } label: {
                                    Text(index == 0 ? "Recommended" : option)
                                        .font(.footnote.weight(.semibold))
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 12)
                                        .background(
                                            (index == 0 ? RotaryTheme.accent.opacity(0.14) : RotaryTheme.softSurface),
                                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled(isWorking)
                            }
                        }

                        HStack(spacing: 8) {
                            liveAssistActionPill(
                                title: "Listen",
                                systemImage: "ear.fill",
                                enabled: true,
                                action: { Task { await control(action: "listen_only") } }
                            )
                            liveAssistActionPill(
                                title: "Join",
                                systemImage: "person.wave.2.fill",
                                enabled: true,
                                action: { Task { await control(action: "join") } }
                            )
                            liveAssistActionPill(
                                title: "Take over",
                                systemImage: "figure.stand",
                                enabled: true,
                                action: { Task { await control(action: "take_over") } }
                            )
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: compact ? 8 : 10) {
                        Text(warmTranscript)
                            .foregroundStyle(.secondary)
                            .lineLimit(compact ? 3 : 4)

                        Text(warmSuggestedNext)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)

                        VStack(spacing: 8) {
                            ForEach(fallbackSteeringOptions, id: \.self) { option in
                                Button {
                                    Task { await steer(selectedOption: option, customText: nil) }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(option)
                                                .font(.footnote.weight(.semibold))
                                                .foregroundStyle(.primary)
                                                .multilineTextAlignment(.leading)
                                        }
                                        Spacer(minLength: 8)
                                        Image(systemName: "arrow.up.right.circle.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(RotaryTheme.accent)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RotaryTheme.softSurface,
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isWorking || call == nil)
                                .opacity((isWorking || call == nil) ? 0.56 : 1)
                            }
                        }

                        HStack(spacing: 8) {
                            liveAssistActionPill(
                                title: "Listen",
                                systemImage: "ear.fill",
                                enabled: call != nil,
                                action: { Task { await control(action: "listen_only") } }
                            )
                            liveAssistActionPill(
                                title: "Join",
                                systemImage: "person.wave.2.fill",
                                enabled: call != nil,
                                action: { Task { await control(action: "join") } }
                            )
                            liveAssistActionPill(
                                title: "Take over",
                                systemImage: "figure.stand",
                                enabled: call != nil,
                                action: { Task { await control(action: "take_over") } }
                            )
                        }
                    }
                }

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
                return
            }

            await reload(for: call)
            while !Task.isCancelled && voiceCoordinator.callPresentationState.presentsActiveCallScreen {
                try? await Task.sleep(for: .seconds(2))
                await reload(for: call)
            }
        }
    }

    private func liveAssistActionPill(
        title: String,
        systemImage: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RotaryTheme.softSurface,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func steer(selectedOption: String?, customText: String?) async {
        guard let call else {
            errorMessage = "Live steer is still preparing."
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            let result = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.steerCall(
                    token: token,
                    callId: call.id,
                    selectedOption: selectedOption,
                    customText: customText?.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            if selectedOption == nil {
                customInstruction = ""
            }
            actionMessage = "Applied: \(result.applied)"
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
    @State private var isWorking = false

    private var warmLiveAssistSummary: String {
        let candidates = [call.summary, call.transcript, voiceCoordinator.lastActionMessage]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        return candidates.first(where: { !$0.isEmpty })
            ?? "Rotary is syncing the live transcript and steering options in the background."
    }

    private var fallbackSteeringOptions: [String] {
        [
            "Ask a clarifying question.",
            "Summarize the last point.",
            "Confirm the caller's preferred next step.",
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RotaryBackdrop()
                ScrollView {
                    VStack(spacing: 16) {
                        headerCard
                        assistContent
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Live Assist")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await reload()
            }
        }
    }

    private var headerCard: some View {
        RotaryGlassCard {
            Text(call.contactName)
                .font(.title2.weight(.bold))
            Text(call.contactPhone ?? call.toNumber ?? call.fromNumber ?? "Unknown number")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var assistContent: some View {
        if let liveAssist {
            liveAssistDetails(liveAssist)
        } else if let errorMessage {
            RotaryGlassCard {
                Text(errorMessage)
            }
        } else {
            RotaryGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Live assist is warming up")
                        .font(.headline)
                    Text(warmLiveAssistSummary)
                        .foregroundStyle(.secondary)
                    Text("You can steer the call now. The live transcript will fill in as soon as Rotary gets the snapshot.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        ForEach(fallbackSteeringOptions, id: \.self) { option in
                            Button {
                                Task { await steer(selectedOption: option, customText: nil) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(option)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: "arrow.up.right.circle.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(RotaryTheme.accent)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RotaryTheme.softSurface,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isWorking)
                            .opacity(isWorking ? 0.56 : 1)
                        }
                    }

                    HStack(spacing: 8) {
                        liveAssistActionPill(
                            title: "Listen",
                            systemImage: "ear.fill",
                            enabled: true,
                            action: { Task { await control(action: "listen_only") } }
                        )
                        liveAssistActionPill(
                            title: "Join",
                            systemImage: "person.wave.2.fill",
                            enabled: true,
                            action: { Task { await control(action: "join") } }
                        )
                        liveAssistActionPill(
                            title: "Take over",
                            systemImage: "figure.stand",
                            enabled: true,
                            action: { Task { await control(action: "take_over") } }
                        )
                    }
                }
            }
        }
    }

    private func liveAssistActionPill(
        title: String,
        systemImage: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RotaryTheme.softSurface,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(isWorking || !enabled)
        .opacity((isWorking || !enabled) ? 0.56 : 1)
    }

    private func liveAssistDetails(_ liveAssist: MobileLiveAssistResponse) -> some View {
        Group {
            RotaryGlassCard {
                Text("Intent")
                    .font(.headline)
                Text(liveAssist.intentSummary)
                    .foregroundStyle(.secondary)
                Divider()
                Text("Suggested next")
                    .font(.headline)
                Text(liveAssist.suggestedNext)
                    .foregroundStyle(.secondary)
                Divider()
                Text("Steering")
                    .font(.headline)
                ForEach(Array(liveAssist.steeringOptions.enumerated()), id: \.offset) { index, option in
                    Button {
                        Task { await steer(selectedOption: option, customText: nil) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(index == 0 ? "Recommended" : "Steer the next move")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if index == 0 {
                                RotaryPill(text: "Recommended", active: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(RotaryTheme.softSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                TextField("Custom steer", text: $customInstruction, axis: .vertical)
                    .lineLimit(1 ... 4)
                    .rotaryTextFieldStyle()
                Button(isWorking ? "Applying..." : "Send custom steer") {
                    Task { await steer(selectedOption: nil, customText: customInstruction) }
                }
                .buttonStyle(RotaryPrimaryButtonStyle())
                .disabled(isWorking || customInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            RotaryGlassCard {
                Text("Call controls")
                    .font(.headline)
                LiveAssistActionGrid(
                    isWorking: isWorking,
                    onJoin: { Task { await control(action: "join") } },
                    onListenOnly: { Task { await control(action: "listen_only") } },
                    onTakeOver: { Task { await control(action: "take_over") } },
                    onResumeAgent: { Task { await control(action: "resume_agent") } },
                    onLeave: { Task { await control(action: "leave") } },
                    onEndCall: { Task { await control(action: "end_call") } }
                )
                if let actionMessage, !actionMessage.isEmpty {
                    Text(actionMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let voiceError = voiceCoordinator.lastError, !voiceError.isEmpty {
                    Text(voiceError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            RotaryGlassCard {
                Text("Transcript")
                    .font(.headline)
                Text(liveAssist.transcript)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func reload() async {
        do {
            liveAssist = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.liveAssist(token: token, callId: call.id)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func steer(selectedOption: String?, customText: String?) async {
        isWorking = true
        defer { isWorking = false }

        do {
            let result = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.steerCall(
                    token: token,
                    callId: call.id,
                    selectedOption: selectedOption,
                    customText: customText?.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            if selectedOption == nil {
                customInstruction = ""
            }
            actionMessage = "Applied: \(result.applied)"
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
}

private struct LiveAssistActionGrid: View {
    let isWorking: Bool
    let onJoin: () -> Void
    let onListenOnly: () -> Void
    let onTakeOver: () -> Void
    let onResumeAgent: () -> Void
    let onLeave: () -> Void
    let onEndCall: () -> Void

    var body: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]

        LazyVGrid(columns: columns, spacing: 10) {
            actionButton("Join", systemImage: "phone.arrow.up.right", action: onJoin)
            actionButton("Listen", systemImage: "ear", action: onListenOnly)
            actionButton("Take over", systemImage: "hand.raised.fill", action: onTakeOver)
            actionButton("Resume agent", systemImage: "arrow.trianglehead.clockwise", action: onResumeAgent)
            actionButton("Leave", systemImage: "arrow.uturn.backward.circle", action: onLeave)
            actionButton("End call", systemImage: "phone.down.fill", destructive: true, action: onEndCall)
        }
    }

    @ViewBuilder
    private func actionButton(
        _ title: String,
        systemImage: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(destructive ? RotaryTheme.destructive : Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RotaryTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .opacity(isWorking ? 0.65 : 1)
    }
}
