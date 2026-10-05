import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import UIKit
@preconcurrency import Vision

#if DEBUG
private let rotaryDebugPendingAgentWorkflowKey = "rotary.debug.pendingAgentWorkflowLaunch"

private struct RotaryPendingAgentWorkflowLaunch: Decodable {
    let agentId: String
    let mode: String
    let prompt: String
    let autoApprove: Bool
    let requestedAt: Date
}
#endif

private struct PendingAgentAttachment: Identifiable {
    let id = UUID()
    let payload: RotaryUploadAttachmentPayload
    let fileName: String
    let kind: String
    var uploadedAttachment: MobileAgentConversationAttachment?
    var queuedAttachmentID: String?
    var isUploading = false

    var detailText: String {
        if isUploading {
            return "Uploading…"
        }
        if uploadedAttachment != nil {
            return "Ready"
        }
        if queuedAttachmentID != nil {
            return "Queued"
        }
        return kind.capitalized
    }
}

struct AgentConversationDetailScreen: View {
    @Environment(\.dismiss) private var dismiss

    let agent: MobileAgent
    let relatedCalls: [MobileCall]
    let relatedThreads: [MobileThreadSummary]
    let messagesStore: MessagesStore
    let api: RotaryAPIClient
    @Bindable var voiceCoordinator: VoiceCoordinator
    let tokenProvider: RotaryTokenProvider
    @Bindable var mutationDispatcher: RotaryMutationDispatcher
    @Bindable var inferenceModeStore: InferenceModeStore
    let localInferenceEngine: LocalInferenceEngine
    let localConversationStore: LocalConversationStore
    let onConversationLoaded: ((MobileAgentConversationPayload) -> Void)?

    @State private var conversationPayload: MobileAgentConversationPayload?
    @State private var conversationMessages: [MobileAgentConversationMessage] = []
    @State private var draft = ""
    @State private var pendingAttachments: [PendingAgentAttachment] = []
    @State private var isLoading = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showingFileImporter = false
    @State private var fileImportTypes: [UTType] = [.pdf, .image, .audio, .plainText]
    @State private var showingMessageSheet = false
    @State private var showingCallSheet = false
    @State private var showingInfo = false
    @State private var seededPhoneNumber = ""
    @State private var callErrorMessage: String?
    @State private var isCallingAgent = false
    @State private var showingCallConfirmation = false
    @State private var attachmentUploadTask: Task<Void, Never>?
    @State private var isRealtimeLocalSession = false
    @State private var composerMode: AgentComposerMode = .none
    @State private var workflowState: AgentWorkflowWidgetState = .idle
    @State private var workflowTask: Task<Void, Never>?
    @State private var selectedCallOfferID: String?
    @State private var activeCallScenario: AgentCallWorkflowScenario?
    @State private var activeCallTranscript: [AgentWorkflowTranscriptLine] = []
    @State private var latestCallSteeringText: String?
    @State private var activeCallTraceTag: String?
    @State private var showingWorkflowDetails = false
    @State private var hasAppliedInitialBottomScroll = false
    @FocusState private var composerFocused: Bool

    init(
        agent: MobileAgent,
        relatedCalls: [MobileCall],
        relatedThreads: [MobileThreadSummary],
        messagesStore: MessagesStore,
        api: RotaryAPIClient,
        voiceCoordinator: VoiceCoordinator,
        tokenProvider: @escaping RotaryTokenProvider,
        mutationDispatcher: RotaryMutationDispatcher,
        inferenceModeStore: InferenceModeStore,
        localInferenceEngine: LocalInferenceEngine = .shared,
        localConversationStore: LocalConversationStore = .shared,
        initialConversation: MobileAgentConversationPayload? = nil,
        onConversationLoaded: ((MobileAgentConversationPayload) -> Void)? = nil
    ) {
        self.agent = agent
        self.relatedCalls = relatedCalls
        self.relatedThreads = relatedThreads
        self.messagesStore = messagesStore
        self.api = api
        self.voiceCoordinator = voiceCoordinator
        self.tokenProvider = tokenProvider
        self.mutationDispatcher = mutationDispatcher
        self.inferenceModeStore = inferenceModeStore
        self.localInferenceEngine = localInferenceEngine
        self.localConversationStore = localConversationStore
        self.onConversationLoaded = onConversationLoaded
        _conversationPayload = State(initialValue: initialConversation)
        _conversationMessages = State(initialValue: initialConversation?.messages ?? [])
    }

    private var transcriptMessages: [RotaryConversationBubbleModel] {
        conversationMessages.map { message in
            RotaryConversationBubbleModel(
                id: message.id,
                direction: message.role == "user" ? .outbound : .inbound,
                text: message.content,
                originalText: message.originalContent,
                sourceLanguage: message.sourceLanguage,
                targetLanguage: message.targetLanguage,
                timestamp: RotaryDateFormatting.messageTimestamp(message.createdAt),
                date: RotaryDateFormatting.parse(message.createdAt),
                deliveryReceipt: agentConversationReceipt(for: message),
                statusSystemImage: providerStatusSymbol(for: message),
                wasTranslated: message.wasTranslated ?? false,
                attachments: message.attachments.map {
                    RotaryConversationAttachmentPreview(
                        id: $0.id,
                        title: $0.fileName,
                        subtitle: $0.extractedText?.nonEmptyTrimmed ?? $0.attachmentKind.capitalized,
                        kind: $0.attachmentKind
                    )
                }
            )
        }
    }

    private var prefersLocalMode: Bool {
        inferenceModeStore.mode == .local
    }

    private var isLocalMode: Bool {
        prefersLocalMode && localInferenceEngine.canExecuteLocally
    }

    private var isWorkflowRunning: Bool {
        workflowState.isRunning
    }

    private var composerPlaceholder: String {
        composerMode.placeholder
    }

    private var shouldShowWorkflowWidget: Bool {
        switch workflowState {
        case .idle:
            return false
        case .awaitingApproval, .running, .cancelled, .completed, .failed:
            return true
        }
    }

    private var usesCachedBootstrapOnly: Bool {
        ProcessInfo.processInfo.environment["ROTARY_USE_CACHED_BOOTSTRAP_ONLY"] == "1"
    }

    var body: some View {
        ZStack {
            RotaryBackdrop(onTap: { composerFocused = false })
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if !transcriptMessages.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                RotaryConversationTranscriptView(messages: transcriptMessages)
                                    .id(transcriptMessages.count)

                                Color.clear
                                    .frame(height: 1)
                                    .id("agent-thread-bottom-anchor")
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                            .padding(.bottom, 24)
                        }
                        .defaultScrollAnchor(.bottom)
                        .scrollDismissesKeyboard(.interactively)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            composerFocused = false
                        }
                        .onAppear {
                            if !hasAppliedInitialBottomScroll {
                                scrollToBottom(proxy: proxy, animated: false)
                                hasAppliedInitialBottomScroll = true
                            }
                        }
                        .onChange(of: conversationMessages.count) { _, _ in
                            scrollToBottom(proxy: proxy, animated: false)
                        }
                    }
                } else {
                    ZStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                composerFocused = false
                            }

                        if let errorMessage, !errorMessage.isEmpty {
                            VStack(spacing: 14) {
                                Circle()
                                    .fill(RotaryTheme.softSurface)
                                    .frame(width: 62, height: 62)
                                    .overlay(
                                        Image(systemName: "exclamationmark.bubble.fill")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(RotaryTheme.warning)
                                    )

                                Text("Couldn’t load this conversation")
                                    .font(.headline)

                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)

                                Button("Retry") {
                                    Task { await loadConversationForCurrentMode(forceRefresh: true) }
                                }
                                .buttonStyle(RotaryPrimaryButtonStyle())
                                .frame(maxWidth: 180)
                            }
                            .padding(.horizontal, 28)
                        } else {
                            emptyConversationState
                        }
                    }
                }

                composer
            }
        }
        .onDisappear {
            composerFocused = false
            workflowTask?.cancel()
            workflowTask = nil
            hasAppliedInitialBottomScroll = false
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    composerFocused = false
                    dismiss()
                } label: {
                    RotaryGlassIcon(systemName: "chevron.left", size: 13, frameSize: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }

            ToolbarItem(placement: .principal) {
                agentConversationHeader
            }

            ToolbarItem(placement: .topBarTrailing) {
                if agent.assignedPhoneNumber != nil {
                    RotaryGlassIconButton(
                        systemName: isCallingAgent ? "phone.badge.waveform" : "phone.fill",
                        showsBackground: true
                    ) {
                        composerFocused = false
                        showingCallConfirmation = true
                    }
                    .disabled(isCallingAgent)
                } else {
                    RotaryGlassIconButton(systemName: "info.circle.fill") {
                        composerFocused = false
                        showingInfo = true
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showingInfo) {
            AgentInfoScreen(
                agent: agent,
                relatedCalls: relatedCalls,
                relatedThreads: relatedThreads,
                conversation: conversationPayload,
                messagesStore: messagesStore,
                api: api,
                voiceCoordinator: voiceCoordinator,
                tokenProvider: tokenProvider
            )
        }
        .task(id: inferenceModeStore.mode.rawValue) {
            await loadConversationForCurrentMode(forceRefresh: true)
        }
#if DEBUG
        .task(id: agent.id) {
            await consumePendingDebugWorkflowLaunchIfNeeded()
        }
#endif
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: fileImportTypes,
            allowsMultipleSelection: true
        ) { result in
            Task { await handleFileSelection(result) }
        }
        .sheet(isPresented: $showingMessageSheet) {
            ProxyMessageSheet(
                fromNumber: agent.assignedPhoneNumber ?? "",
                initialToNumber: seededPhoneNumber,
                messagesStore: messagesStore
            )
        }
        .sheet(isPresented: $showingCallSheet) {
            ProxyCallSheet(
                fromNumber: agent.assignedPhoneNumber ?? "",
                initialPhoneNumber: seededPhoneNumber,
                startNativeCall: { phoneNumber in
                    guard ConnectivityMonitor.shared.isOnline else {
                        throw VoiceCoordinatorError.nativeVoiceUnavailable("You're offline. Reconnect to start a call.")
                    }
                    guard let lineId = agent.assignedLineId else {
                        throw VoiceCoordinatorError.missingLine
                    }
                    try await voiceCoordinator.startLineCall(
                        to: phoneNumber,
                        lineId: lineId,
                        handle: phoneNumber
                    )
                }
            )
        }
        .sheet(isPresented: $showingWorkflowDetails) {
            NavigationStack {
                ZStack {
                    RotaryBackdrop()
                    ScrollView {
                        RotaryAgentWorkflowWidgetCard(
                            state: workflowState,
                            selectedCallOfferID: selectedCallOfferID,
                            onApprove: {
                                Task { await approveWorkflow() }
                            },
                            onModify: {
                                modifyWorkflowDraft()
                            },
                            onStop: {
                                cancelWorkflow()
                            },
                            onDismiss: {
                                workflowState = .idle
                                selectedCallOfferID = nil
                                showingWorkflowDetails = false
                            },
                            onSelectCallOffer: { offer in
                                selectedCallOfferID = offer.id
                                draft = "Proceed with \(offer.providerName) at \(offer.priceText)."
                                composerFocused = true
                                RotaryHaptics.success()
                            },
                            onApplySteering: { option in
                                applyWorkflowSteering(option)
                            },
                            onCopyReport: { reportText in
                                UIPasteboard.general.string = reportText
                                RotaryHaptics.success()
                            },
                            presentation: .expanded,
                            onOpenDetails: nil
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                    }
                }
                .navigationTitle("Call Run Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingWorkflowDetails = false
                        } label: {
                            RotaryGlassIcon(systemName: "xmark", size: 12, frameSize: 34)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("Call Error", isPresented: Binding(
            get: { callErrorMessage != nil },
            set: { if !$0 { callErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(callErrorMessage ?? "")
        }
        .confirmationDialog(
            "Call \(agent.name)?",
            isPresented: $showingCallConfirmation,
            titleVisibility: .visible
        ) {
            Button("Call") {
                Task { await callAgent() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(agent.assignedPhoneNumber ?? "Start a call with this agent.")
        }
    }

    private func providerStatusSymbol(for message: MobileAgentConversationMessage) -> String? {
        guard let provider = message.provider?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !provider.isEmpty else {
            return nil
        }

        if provider.contains("local") || provider.contains("offline") || provider.contains("ondevice") {
            return "iphone.gen3"
        }
        return "cloud.fill"
    }

    private func agentConversationReceipt(for message: MobileAgentConversationMessage) -> RotaryMessageDeliveryReceipt? {
        guard message.role == "user" else { return nil }
        let status = message.deliveryStatus?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        switch status {
        case "sent":
            return .sent
        case "delivered":
            return .delivered
        case "read":
            return .read
        case "undelivered", "failed":
            return .undelivered
        default:
            return .delivered
        }
    }

    private var composer: some View {
        VStack(spacing: 6) {
            if shouldShowWorkflowWidget {
                RotaryAgentWorkflowWidgetCard(
                    state: workflowState,
                    selectedCallOfferID: selectedCallOfferID,
                    onApprove: {
                        Task { await approveWorkflow() }
                    },
                    onModify: {
                        modifyWorkflowDraft()
                    },
                    onStop: {
                        cancelWorkflow()
                    },
                    onDismiss: {
                        workflowState = .idle
                        selectedCallOfferID = nil
                    },
                    onSelectCallOffer: { offer in
                        selectedCallOfferID = offer.id
                        draft = "Proceed with \(offer.providerName) at \(offer.priceText)."
                        composerFocused = true
                        RotaryHaptics.success()
                    },
                    onApplySteering: { option in
                        applyWorkflowSteering(option)
                    },
                    onCopyReport: { reportText in
                        UIPasteboard.general.string = reportText
                        RotaryHaptics.success()
                    },
                    presentation: .compact,
                    onOpenDetails: {
                        showingWorkflowDetails = true
                    }
                )
                .padding(.horizontal, 12)
            }

            if composerMode != .none {
                HStack {
                    HStack(spacing: 8) {
                        Text(composerMode.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)

                        Button {
                            RotaryHaptics.selection()
                            composerMode = .none
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(RotaryTheme.elevatedSurface, in: Capsule())

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
            }

            if !pendingAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pendingAttachments) { attachment in
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(attachment.fileName)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                    Text(attachment.detailText)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Button {
                                    pendingAttachments.removeAll { $0.id == attachment.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(RotaryTheme.elevatedSurface, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }

            if !transcriptMessages.isEmpty, let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
            }

            RotaryComposerBar(
                text: $draft,
                placeholder: composerPlaceholder,
                isWorking: isSending || isWorkflowRunning,
                isFocused: $composerFocused,
                onMic: {
                    handleMicTap()
                },
                onSend: {
                    Task { await send() }
                }
            ) {
                Button("Deep Research", systemImage: "text.page.badge.magnifyingglass") {
                    setComposerMode(.deepResearch)
                }
                Button("Make a Call", systemImage: "phone.badge.waveform") {
                    setComposerMode(.makeCall)
                }
                Button("Web Search", systemImage: "globe") {
                    setComposerMode(.webSearch)
                }
                Button("Create Image", systemImage: "sparkles.rectangle.stack") {
                    setComposerMode(.createImage)
                }
                Divider()
                Button("Camera", systemImage: "camera.fill") {
                    fileImportTypes = [.image]
                    showingFileImporter = true
                }
                Button("Photos", systemImage: "photo.on.rectangle") {
                    fileImportTypes = [.image]
                    showingFileImporter = true
                }
                Button("Audio", systemImage: "waveform") {
                    fileImportTypes = [.audio]
                    showingFileImporter = true
                }
                Button("Send Later", systemImage: "clock.badge") {
                    appendDraftDirective("[Send later request]")
                }
                Button("Add Files", systemImage: "paperclip") {
                    fileImportTypes = [.pdf, .image, .audio, .plainText]
                    showingFileImporter = true
                }
            }
        }
        .padding(.bottom, 10)
    }

    @MainActor
    private func appendDraftDirective(_ directive: String) {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = trimmed.isEmpty ? directive : "\(directive)\n\(trimmed)"
        composerFocused = true
    }

    @MainActor
    private func setComposerMode(_ mode: AgentComposerMode) {
        composerMode = mode
        RotaryHaptics.selection()
        composerFocused = true
    }

    @MainActor
    private func callAgent() async {
        guard let phoneNumber = agent.assignedPhoneNumber else {
            callErrorMessage = "Rotary is still provisioning this agent’s line."
            return
        }
        guard ConnectivityMonitor.shared.isOnline else {
            callErrorMessage = "You're offline. Reconnect to start a call."
            return
        }

        isCallingAgent = true
        defer { isCallingAgent = false }

        do {
            try await voiceCoordinator.startOwnerCall(to: phoneNumber, handle: agent.name)
        } catch {
            callErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadConversationForCurrentMode(forceRefresh: Bool = false) async {
        let cachedMessages = await localConversationStore.messages(for: agent.id)
        if !cachedMessages.isEmpty && conversationMessages.isEmpty {
            conversationMessages = cachedMessages
        }

        if usesCachedBootstrapOnly {
            errorMessage = nil
            return
        }

        if prefersLocalMode {
            await localInferenceEngine.warmupIfNeeded()
            if !localInferenceEngine.canExecuteLocally {
                inferenceModeStore.mode = .cloud
                errorMessage = localInferenceEngine.fallbackMessage
            }
        }

        guard ConnectivityMonitor.shared.isOnline else {
            errorMessage = conversationMessages.isEmpty ? nil : errorMessage
            return
        }

        await loadCloudConversation(forceRefresh: forceRefresh)
    }

    @MainActor
    private func loadCloudConversation(forceRefresh: Bool = false) async {
        if usesCachedBootstrapOnly {
            errorMessage = nil
            return
        }

        let cachedMessages = await localConversationStore.messages(for: agent.id)
        let shouldShowPrimaryLoading = conversationPayload == nil && conversationMessages.isEmpty
        if shouldShowPrimaryLoading {
            isLoading = true
        }
        defer {
            if shouldShowPrimaryLoading {
                isLoading = false
            }
        }

        do {
            let payload = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.agentConversation(
                    token: token,
                    agentId: agent.id,
                    forceRefresh: forceRefresh
                )
            }
            let mergedMessages = mergeConversationMessages(remote: payload.messages, cached: cachedMessages)
            conversationPayload = payload
            conversationMessages = mergedMessages
            await localConversationStore.replaceMessages(mergedMessages, for: agent.id)
            errorMessage = nil
            onConversationLoaded?(payload)
        } catch {
            if shouldShowPrimaryLoading, cachedMessages.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func refreshCloudConversationSilently(forceRefresh: Bool = false) async {
        if usesCachedBootstrapOnly {
            return
        }

        do {
            let payload = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.agentConversation(
                    token: token,
                    agentId: agent.id,
                    forceRefresh: forceRefresh
                )
            }
            let cachedMessages = await localConversationStore.messages(for: agent.id)
            let mergedMessages = mergeConversationMessages(remote: payload.messages, cached: cachedMessages)
            conversationPayload = payload
            conversationMessages = mergedMessages
            await localConversationStore.replaceMessages(mergedMessages, for: agent.id)
            errorMessage = nil
            onConversationLoaded?(payload)
        } catch {
            // Keep the last rendered content stable when background refresh fails.
        }
    }

    @MainActor
    private func send() async {
        guard !isWorkflowRunning else { return }

        let trimmedMessage = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty || !pendingAttachments.isEmpty else { return }

        if composerMode == .deepResearch || composerMode == .makeCall {
            guard !trimmedMessage.isEmpty else {
                errorMessage = "Add a request first."
                return
            }
            beginWorkflowDraft(mode: composerMode, prompt: trimmedMessage)
            draft = ""
            return
        }

        let outgoingMessage = messageWithModeDirective(trimmedMessage)

        if prefersLocalMode {
            await localInferenceEngine.warmupIfNeeded()
            if !localInferenceEngine.canExecuteLocally {
                inferenceModeStore.mode = .cloud
                errorMessage = localInferenceEngine.fallbackMessage
            }
        }

        if isLocalMode {
            await sendLocal(trimmedMessage: outgoingMessage)
        } else {
            await sendCloud(trimmedMessage: outgoingMessage)
        }
    }

    @MainActor
    private func sendCloud(trimmedMessage: String) async {
        if let attachmentUploadTask {
            await attachmentUploadTask.value
        }

        isSending = true
        defer { isSending = false }
        errorMessage = nil

        let attachmentSnapshot = pendingAttachments

        do {
            let attachmentIDs = try await ensureUploadedPendingAttachments()
            let dispatchResult = try await mutationDispatcher.sendAgentConversationMessage(
                agentId: agent.id,
                message: trimmedMessage.isEmpty ? nil : trimmedMessage,
                attachmentIds: attachmentIDs,
                thinkingMode: agent.thinkingMode ?? "balanced"
            )

            switch dispatchResult {
            case .executed(let response):
                draft = ""
                pendingAttachments = []
                composerMode = .none
                conversationMessages.append(response.message)
                await persistConversationCache()
                await refreshCloudConversationSilently(forceRefresh: true)
            case .queued:
                let optimisticMessage = makeConversationMessage(
                    role: "user",
                    content: trimmedMessage,
                    deliveryStatus: "sent",
                    provider: nil,
                    thinkingMode: agent.thinkingMode,
                    attachments: conversationAttachments(from: attachmentSnapshot)
                )
                conversationMessages.append(optimisticMessage)
                draft = ""
                pendingAttachments = []
                composerMode = .none
                errorMessage = "Message queued offline. Rotary will sync it when you're back online."
                await persistConversationCache()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func sendLocal(trimmedMessage: String) async {
        isSending = true
        defer { isSending = false }
        errorMessage = nil

        let attachmentSnapshot = pendingAttachments
        let conversationAttachments = conversationAttachments(from: attachmentSnapshot)
        let localAttachments = localInferenceAttachments(from: attachmentSnapshot)

        if !trimmedMessage.isEmpty || !conversationAttachments.isEmpty {
            let userMessage = makeConversationMessage(
                role: "user",
                content: trimmedMessage,
                deliveryStatus: "delivered",
                provider: nil,
                thinkingMode: agent.thinkingMode,
                attachments: conversationAttachments
            )
            conversationMessages.append(userMessage)
            await persistConversationCache()
        }

        do {
            let output = try await localInferenceEngine.generate(
                input: LocalInferenceInput(
                    prompt: trimmedMessage,
                    thinkingMode: agent.thinkingMode ?? "balanced",
                    attachments: localAttachments,
                    isRealtimeSession: isRealtimeLocalSession,
                    conversationHistory: localConversationHistory(from: conversationMessages)
                )
            )

            let assistantMessage = makeConversationMessage(
                role: "assistant",
                content: output.text,
                provider: output.modelID,
                thinkingMode: agent.thinkingMode,
                attachments: []
            )

            conversationMessages.append(assistantMessage)
            await persistConversationCache()
            draft = ""
            pendingAttachments = []
            composerMode = .none
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func messageWithModeDirective(_ trimmedMessage: String) -> String {
        switch composerMode {
        case .webSearch:
            return "[Web search]\n\(trimmedMessage)"
        case .createImage:
            return "[Create image]\n\(trimmedMessage)"
        case .none, .deepResearch, .makeCall:
            return trimmedMessage
        }
    }

    @MainActor
    private func beginWorkflowDraft(mode: AgentComposerMode, prompt: String) {
        workflowTask?.cancel()
        workflowTask = nil
        selectedCallOfferID = nil
        activeCallScenario = nil
        activeCallTranscript = []
        latestCallSteeringText = nil
        activeCallTraceTag = nil
        workflowState = .awaitingApproval(
            mode: mode,
            prompt: prompt,
            checklist: workflowChecklist(for: mode),
            payload: workflowDraftPayload(for: mode)
        )
        errorMessage = nil
        composerFocused = false
        RotaryHaptics.selection()
    }

    @MainActor
    private func approveWorkflow() async {
        guard case let .awaitingApproval(mode, prompt, _, _) = workflowState else { return }

        workflowTask?.cancel()
        workflowTask = Task { @MainActor in
            await executeWorkflow(mode: mode, prompt: prompt)
            workflowTask = nil
        }
    }

    @MainActor
    private func modifyWorkflowDraft() {
        guard case let .awaitingApproval(_, prompt, _, _) = workflowState else { return }
        draft = prompt
        workflowState = .idle
        composerFocused = true
    }

    @MainActor
    private func cancelWorkflow() {
        workflowTask?.cancel()
        workflowTask = nil

        switch workflowState {
        case let .running(mode, _, _, _, _, _):
            workflowState = .cancelled(mode: mode)
        case let .awaitingApproval(mode, _, _, _):
            workflowState = .cancelled(mode: mode)
        default:
            break
        }
    }

    @MainActor
    private func applyWorkflowSteering(_ option: String) {
        guard case let .running(mode, prompt, stepIndex, steps, _, payload) = workflowState,
              mode == .makeCall,
              case var .makeCall(makeCallPayload) = payload else {
            return
        }

        let trimmed = option.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        latestCallSteeringText = trimmed
        let steerLine = AgentWorkflowTranscriptLine(
            id: "steer-\(UUID().uuidString)",
            speaker: "Live Steering",
            text: trimmed,
            latencyMs: nil,
            isTranslated: false,
            originalText: nil,
            sourceLanguage: nil,
            targetLanguage: nil
        )
        makeCallPayload = MakeCallRunningPayload(
            timeline: makeCallPayload.timeline,
            phaseTitle: makeCallPayload.phaseTitle,
            elapsedLabel: makeCallPayload.elapsedLabel,
            participants: makeCallPayload.participants,
            transcript: Array((makeCallPayload.transcript + [steerLine]).suffix(9)),
            steeringChoices: makeCallPayload.steeringChoices,
            latestSteeringText: trimmed
        )

        workflowState = .running(
            mode: mode,
            prompt: prompt,
            stepIndex: stepIndex,
            steps: steps,
            detail: "Steer applied: \(trimmed)",
            payload: .makeCall(makeCallPayload)
        )
        RotaryLogger.trace(
            "agent_call steer applied trace=\(activeCallTraceTag ?? "n/a") option=\(trimmed)",
            category: "agent-call"
        )
        RotaryHaptics.selection()
    }

    @MainActor
    private func executeWorkflow(mode: AgentComposerMode, prompt: String) async {
        if mode == .makeCall {
            await executeMakeCallWorkflow(prompt: prompt)
            return
        }

        let steps = workflowProgressSteps(for: mode)
        for (index, step) in steps.enumerated() {
            if Task.isCancelled {
                workflowState = .cancelled(mode: mode)
                return
            }

            workflowState = .running(
                mode: mode,
                prompt: prompt,
                stepIndex: index,
                steps: steps,
                detail: step,
                payload: workflowRunningPayload(for: mode, stepIndex: index, steps: steps, prompt: prompt)
            )
            try? await Task.sleep(for: .milliseconds(780))
        }

        if Task.isCancelled {
            workflowState = .cancelled(mode: mode)
            return
        }

        if usesCachedBootstrapOnly {
            await persistConversationCache()
        } else {
            let workflowPrompt = """
            [\(mode.title)]
            \(prompt)
            """

            if isLocalMode {
                await sendLocal(trimmedMessage: workflowPrompt)
            } else {
                await sendCloud(trimmedMessage: workflowPrompt)
            }

            if let errorMessage, !errorMessage.isEmpty {
                workflowState = .failed(mode: mode, message: errorMessage)
                return
            }
        }

        workflowState = .completed(
            mode: mode,
            summary: workflowSummary(for: mode),
            details: workflowResultDetails(for: mode),
            payload: workflowCompletionPayload(for: mode)
        )
        RotaryHaptics.success()
    }

    @MainActor
    private func executeMakeCallWorkflow(prompt: String) async {
        let scenario = AgentCallWorkflowScenario.build(prompt: prompt)
        activeCallScenario = scenario
        activeCallTraceTag = "call-run-\(UUID().uuidString.prefix(8))"
        activeCallTranscript = []
        latestCallSteeringText = nil
        selectedCallOfferID = scenario.recommendedOfferID

        let userMessage = makeConversationMessage(
            role: "user",
            content: prompt,
            originalContent: nil,
            sourceLanguage: nil,
            targetLanguage: nil,
            wasTranslated: nil,
            deliveryStatus: "sent",
            provider: nil,
            thinkingMode: agent.thinkingMode,
            attachments: []
        )
        conversationMessages.append(userMessage)
        await persistConversationCache()

        RotaryLogger.trace(
            "agent_call started trace=\(activeCallTraceTag ?? "n/a") prompt=\(prompt)",
            category: "agent-call"
        )

        let steps = scenario.stages.map(\.detail)
        for (index, stage) in scenario.stages.enumerated() {
            if Task.isCancelled {
                workflowState = .cancelled(mode: .makeCall)
                RotaryLogger.trace(
                    "agent_call cancelled trace=\(activeCallTraceTag ?? "n/a") stage=\(stage.id)",
                    category: "agent-call",
                    level: "warning"
                )
                return
            }

            activeCallTranscript.append(contentsOf: stage.transcriptLines)
            activeCallTranscript = Array(activeCallTranscript.suffix(9))

            if let steering = latestCallSteeringText,
               !steering.isEmpty,
               activeCallTranscript.last?.speaker != "Live Steering" {
                activeCallTranscript.append(
                    AgentWorkflowTranscriptLine(
                        id: "steer-stage-\(index)",
                        speaker: "Live Steering",
                        text: steering,
                        latencyMs: nil,
                        isTranslated: false,
                        originalText: nil,
                        sourceLanguage: nil,
                        targetLanguage: nil
                    )
                )
                activeCallTranscript = Array(activeCallTranscript.suffix(9))
            }

            let payload = MakeCallRunningPayload(
                timeline: stage.timeline,
                phaseTitle: stage.phaseTitle,
                elapsedLabel: rotaryWorkflowElapsedLabel(seconds: stage.elapsedSeconds),
                participants: stage.participants,
                transcript: activeCallTranscript,
                steeringChoices: stage.steeringChoices,
                latestSteeringText: latestCallSteeringText
            )

            workflowState = .running(
                mode: .makeCall,
                prompt: prompt,
                stepIndex: index,
                steps: steps,
                detail: stage.detail,
                payload: .makeCall(payload)
            )

            RotaryLogger.trace(
                "agent_call trace=\(activeCallTraceTag ?? "n/a") stage=\(stage.id) elapsed=\(stage.elapsedSeconds)s note=\(stage.traceMessage)",
                category: "agent-call"
            )
            try? await Task.sleep(for: .milliseconds(stage.renderDelayMs))
        }

        if Task.isCancelled {
            workflowState = .cancelled(mode: .makeCall)
            return
        }

        let summaryText = """
        Call run complete.

        Request: \(scenario.prompt)
        Findings were assembled into a concise report in the conversation.
        You can refine the scope and run again from the same mode.
        """
        let summaryMessage = makeConversationMessage(
            role: "assistant",
            content: summaryText,
            originalContent: nil,
            sourceLanguage: nil,
            targetLanguage: nil,
            wasTranslated: nil,
            deliveryStatus: nil,
            provider: "rotary-call-orchestrator",
            thinkingMode: agent.thinkingMode,
            attachments: []
        )
        conversationMessages.append(summaryMessage)

        let translatedRecap = makeConversationMessage(
            role: "assistant",
            content: "Owner recap: GreenEdge confirmed tomorrow morning at $85.",
            originalContent: "소유자 요약: GreenEdge가 내일 오전 $85로 확정했어요.",
            sourceLanguage: "ko",
            targetLanguage: "en",
            wasTranslated: true,
            deliveryStatus: nil,
            provider: "rotary-translation",
            thinkingMode: agent.thinkingMode,
            attachments: []
        )
        conversationMessages.append(translatedRecap)
        await persistConversationCache()

        let report = scenario.reportText(
            traceTag: activeCallTraceTag ?? "n/a",
            selectedOfferID: selectedCallOfferID
        )
        workflowState = .completed(
            mode: .makeCall,
            summary: workflowSummary(for: .makeCall),
            details: workflowResultDetails(for: .makeCall),
            payload: .makeCall(
                MakeCallCompletionPayload(
                    offers: scenario.offers,
                    recommendedOfferID: scenario.recommendedOfferID,
                    highlights: scenario.highlights,
                    metrics: scenario.metrics,
                    reportText: report
                )
            )
        )
        composerMode = .none
        RotaryLogger.trace(
            "agent_call completed trace=\(activeCallTraceTag ?? "n/a") offers=\(scenario.offers.count)",
            category: "agent-call"
        )
        RotaryHaptics.success()
    }

    private func workflowChecklist(for mode: AgentComposerMode) -> [String] {
        switch mode {
        case .deepResearch:
            return [
                "Confirm scope and key questions",
                "Prioritize reliable sources",
                "Define report format and depth",
            ]
        case .makeCall:
            return [
                "Confirm address and service size",
                "Confirm budget and preferred timing",
                "Confirm callback and approval rules",
            ]
        case .webSearch, .createImage, .none:
            return []
        }
    }

    private func workflowProgressSteps(for mode: AgentComposerMode) -> [String] {
        switch mode {
        case .deepResearch:
            return [
                "Scoping the research plan",
                "Gathering supporting context",
                "Synthesizing findings",
                "Preparing recommendation summary",
            ]
        case .makeCall:
            return [
                "Gathering call requirements",
                "Finding candidate providers",
                "Calling and comparing quotes",
                "Preparing ranked options",
            ]
        case .webSearch, .createImage, .none:
            return []
        }
    }

    private func workflowSummary(for mode: AgentComposerMode) -> String {
        switch mode {
        case .deepResearch:
            return "Research run complete."
        case .makeCall:
            return "Call automation complete."
        case .webSearch, .createImage, .none:
            return "Complete."
        }
    }

    private func workflowResultDetails(for mode: AgentComposerMode) -> [String] {
        switch mode {
        case .deepResearch:
            return [
                "Findings were assembled into a concise report in the conversation.",
                "You can refine the scope and run again from the same mode.",
            ]
        case .makeCall:
            return [
                "Providers were called and ranked by price and timing.",
                "Select an offer below to continue.",
            ]
        case .webSearch, .createImage, .none:
            return []
        }
    }

#if DEBUG
    @MainActor
    private func consumePendingDebugWorkflowLaunchIfNeeded() async {
        guard workflowState == .idle else { return }
        guard let data = UserDefaults.standard.data(forKey: rotaryDebugPendingAgentWorkflowKey) else { return }
        guard let pending = try? JSONDecoder().decode(RotaryPendingAgentWorkflowLaunch.self, from: data) else {
            UserDefaults.standard.removeObject(forKey: rotaryDebugPendingAgentWorkflowKey)
            return
        }
        guard pending.agentId == agent.id else { return }

        UserDefaults.standard.removeObject(forKey: rotaryDebugPendingAgentWorkflowKey)
        let normalizedMode = pending.mode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let workflowMode: AgentComposerMode
        switch normalizedMode {
        case "make_call", "makecall", "call":
            workflowMode = .makeCall
        case "deep_research", "deepresearch", "research":
            workflowMode = .deepResearch
        case "web_search", "websearch":
            workflowMode = .webSearch
        case "create_image", "createimage", "image":
            workflowMode = .createImage
        default:
            workflowMode = .makeCall
        }

        let prompt = pending.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        beginWorkflowDraft(mode: workflowMode, prompt: prompt)
        RotaryLogger.trace(
            "agent_workflow_debug consumed mode=\(normalizedMode) agent=\(agent.id) autoApprove=\(pending.autoApprove)",
            category: "agent-call"
        )

        if pending.autoApprove {
            try? await Task.sleep(for: .milliseconds(400))
            await approveWorkflow()
        }
    }
#endif

    private func workflowDraftPayload(for mode: AgentComposerMode) -> AgentWorkflowDraftPayload? {
        switch mode {
        case .deepResearch:
            return .deepResearch(
                DeepResearchDraftPayload(
                    skeletonQueries: [
                        "Scope core requirements",
                        "Collect current options and constraints",
                        "Rank recommendations with tradeoffs",
                    ],
                    approvalHint: "Approve to start. Modify to tighten the scope first."
                )
            )
        case .makeCall:
            return .makeCall(
                MakeCallDraftPayload(
                    requiredQuestions: [
                        AgentWorkflowQuestion(
                            id: "address",
                            title: "Confirm address",
                            detail: "Service location and access notes.",
                            isRequired: true
                        ),
                        AgentWorkflowQuestion(
                            id: "size",
                            title: "Confirm property size",
                            detail: "Lawn size or service scope.",
                            isRequired: true
                        ),
                        AgentWorkflowQuestion(
                            id: "budget",
                            title: "Confirm budget",
                            detail: "Target range and hard max.",
                            isRequired: true
                        ),
                        AgentWorkflowQuestion(
                            id: "timing",
                            title: "Confirm timing",
                            detail: "Preferred date and time windows.",
                            isRequired: true
                        ),
                        AgentWorkflowQuestion(
                            id: "callback",
                            title: "Confirm callback preference",
                            detail: "How Rotary should report and finalize.",
                            isRequired: false
                        ),
                    ]
                )
            )
        case .webSearch, .createImage, .none:
            return nil
        }
    }

    private func workflowRunningPayload(
        for mode: AgentComposerMode,
        stepIndex: Int,
        steps: [String],
        prompt: String
    ) -> AgentWorkflowRunningPayload? {
        switch mode {
        case .deepResearch:
            return .deepResearch(
                DeepResearchRunningPayload(
                    reasoningSnippet: steps[stepIndex],
                    sourceLabels: [
                        "Public web sources",
                        "Prior conversation context",
                        "Internal heuristics",
                    ]
                )
            )
        case .makeCall:
            let timeline = [
                AgentWorkflowTimelineEvent(
                    id: "discover",
                    title: "Provider shortlist",
                    subtitle: stepIndex >= 1 ? "GreenEdge, RapidLawn, Sunrise" : "Scanning local options",
                    symbol: "list.bullet.rectangle"
                ),
                AgentWorkflowTimelineEvent(
                    id: "dial",
                    title: "Dialing and negotiating",
                    subtitle: stepIndex >= 2 ? "Collecting price + schedule confirmations" : "Waiting for provider responses",
                    symbol: "phone.connection.fill"
                ),
                AgentWorkflowTimelineEvent(
                    id: "compare",
                    title: "Preparing comparison card",
                    subtitle: stepIndex >= 3 ? "Ranking by price and timing fit" : "Pending call results",
                    symbol: "chart.bar.doc.horizontal.fill"
                ),
            ]
            return .makeCall(
                MakeCallRunningPayload(
                    timeline: timeline,
                    phaseTitle: "Call in progress",
                    elapsedLabel: rotaryWorkflowElapsedLabel(seconds: (stepIndex + 1) * 32),
                    participants: [
                        AgentWorkflowParticipant(id: "planner", name: "Planner Agent", role: "Acting", state: .active),
                        AgentWorkflowParticipant(id: "caller", name: "Caller Agent", role: "Execution", state: stepIndex >= 1 ? .active : .standby),
                        AgentWorkflowParticipant(id: "owner", name: "Owner", role: "Authorization", state: stepIndex >= 2 ? .left : .standby),
                        AgentWorkflowParticipant(id: "provider", name: "Provider", role: "External", state: stepIndex >= 1 ? .active : .standby),
                    ],
                    transcript: [],
                    steeringChoices: [
                        AgentWorkflowSteeringChoice(id: "budget-cap", title: "Cap quote at $95 before approval", isRecommended: true),
                        AgentWorkflowSteeringChoice(id: "expedite", title: "Prioritize earliest arrival even if pricier", isRecommended: false),
                        AgentWorkflowSteeringChoice(id: "confirm-license", title: "Require license + insurance confirmation", isRecommended: false),
                    ],
                    latestSteeringText: latestCallSteeringText
                )
            )
        case .webSearch, .createImage, .none:
            _ = prompt
            return nil
        }
    }

    private func workflowCompletionPayload(for mode: AgentComposerMode) -> AgentWorkflowCompletionPayload? {
        switch mode {
        case .deepResearch:
            return .deepResearch(
                DeepResearchCompletionPayload(
                    reportOutline: [
                        "Executive summary",
                        "Options ranked by fit",
                        "Recommendation and next step",
                    ]
                )
            )
        case .makeCall:
            let offers: [AgentCallOffer] = [
                AgentCallOffer(
                    id: "greenedge",
                    providerName: "GreenEdge Landscaping",
                    phoneNumber: "(951) 555-0181",
                    priceText: "$85",
                    availabilityText: "Tomorrow 9:00–11:00 AM",
                    weatherSummary: "Clear, 74°F",
                    mapSummary: "18 min away",
                    notes: "Best overall fit for budget and timing."
                ),
                AgentCallOffer(
                    id: "rapidlawn",
                    providerName: "RapidLawn Services",
                    phoneNumber: "(951) 555-0133",
                    priceText: "$95",
                    availabilityText: "Tomorrow 1:00–3:00 PM",
                    weatherSummary: "Partly cloudy, 72°F",
                    mapSummary: "12 min away",
                    notes: "Fastest arrival window."
                ),
                AgentCallOffer(
                    id: "sunrise",
                    providerName: "Sunrise Yard Care",
                    phoneNumber: "(951) 555-0199",
                    priceText: "$110",
                    availabilityText: "Tomorrow 8:00–10:00 AM",
                    weatherSummary: "Sunny, 75°F",
                    mapSummary: "26 min away",
                    notes: "Higher price but strongest customer rating."
                ),
            ]
            return .makeCall(
                MakeCallCompletionPayload(
                    offers: offers,
                    recommendedOfferID: offers.first?.id,
                    highlights: [
                        "Providers were called and ranked by price and timing.",
                        "Owner authorization was captured without blocking execution.",
                    ],
                    metrics: [
                        AgentWorkflowMetric(id: "duration", title: "Virtual call span", value: "05:01", detail: "Accelerated playback in app"),
                        AgentWorkflowMetric(id: "avg-latency", title: "Avg transcript latency", value: "292 ms", detail: "Speaker-tagged turn processing"),
                    ],
                    reportText: "Run this call workflow to generate a full report."
                )
            )
        case .webSearch, .createImage, .none:
            return nil
        }
    }

    @MainActor
    private func ensureUploadedPendingAttachments() async throws -> [String] {
        guard !pendingAttachments.isEmpty else { return [] }

        var attachmentIDs: [String] = []
        let attachmentTokens = pendingAttachments.map(\.id)
        for attachmentToken in attachmentTokens {
            guard let currentIndex = pendingAttachments.firstIndex(where: { $0.id == attachmentToken }) else {
                continue
            }

            if let uploadedAttachment = pendingAttachments[currentIndex].uploadedAttachment {
                attachmentIDs.append(uploadedAttachment.id)
                continue
            }

            if let queuedAttachmentID = pendingAttachments[currentIndex].queuedAttachmentID {
                attachmentIDs.append(queuedAttachmentID)
                continue
            }

            let payload = pendingAttachments[currentIndex].payload
            let tempAttachmentID = "temp-attachment:\(attachmentToken.uuidString)"
            pendingAttachments[currentIndex].isUploading = true

            do {
                let result = try await mutationDispatcher.uploadAgentAttachment(
                    agentId: agent.id,
                    tempID: tempAttachmentID,
                    payload: payload
                )

                guard let resultIndex = pendingAttachments.firstIndex(where: { $0.id == attachmentToken }) else {
                    continue
                }

                switch result {
                case .executed(let response):
                    pendingAttachments[resultIndex].uploadedAttachment = response.attachment
                    pendingAttachments[resultIndex].queuedAttachmentID = nil
                    attachmentIDs.append(response.attachment.id)
                case .queued:
                    pendingAttachments[resultIndex].queuedAttachmentID = tempAttachmentID
                    attachmentIDs.append(tempAttachmentID)
                }

                pendingAttachments[resultIndex].isUploading = false
            } catch {
                if let resultIndex = pendingAttachments.firstIndex(where: { $0.id == attachmentToken }) {
                    pendingAttachments[resultIndex].isUploading = false
                }
                throw error
            }
        }

        return attachmentIDs
    }

    @MainActor
    private func handleFileSelection(_ result: Result<[URL], Error>) async {
        do {
            let urls = try result.get()
            var prepared: [PendingAgentAttachment] = []
            for url in urls {
                prepared.append(try await preparePendingAttachment(from: url))
            }
            pendingAttachments.append(contentsOf: prepared)
            errorMessage = nil
            startAttachmentUploadWarmup()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func startAttachmentUploadWarmup() {
        guard !isLocalMode else { return }
        guard attachmentUploadTask == nil else { return }
        guard pendingAttachments.contains(where: { $0.uploadedAttachment == nil && $0.queuedAttachmentID == nil }) else { return }

        attachmentUploadTask = Task { @MainActor in
            defer { attachmentUploadTask = nil }

            while !Task.isCancelled {
                let needsUpload = pendingAttachments.contains {
                    $0.uploadedAttachment == nil && $0.queuedAttachmentID == nil && !$0.isUploading
                }
                guard needsUpload else { break }

                do {
                    _ = try await ensureUploadedPendingAttachments()
                    errorMessage = nil
                } catch is CancellationError {
                    break
                } catch {
                    errorMessage = error.localizedDescription
                    break
                }
            }
        }
    }

    @MainActor
    private func persistConversationCache() async {
        await localConversationStore.replaceMessages(conversationMessages, for: agent.id)
    }

    @MainActor
    private func handleMicTap() {
        composerFocused = true
        guard isLocalMode else { return }
        isRealtimeLocalSession = true
    }

    private func conversationAttachments(from pending: [PendingAgentAttachment]) -> [MobileAgentConversationAttachment] {
        let createdAt = ISO8601DateFormatter().string(from: Date())
        return pending.map { attachment in
            MobileAgentConversationAttachment(
                id: attachment.uploadedAttachment?.id ?? attachment.queuedAttachmentID ?? "local-attachment-\(UUID().uuidString)",
                fileName: attachment.fileName,
                mimeType: attachment.payload.mimeType,
                fileSize: attachment.payload.data.count,
                attachmentKind: attachment.kind,
                extractedText: attachment.payload.extractedText,
                previewUrl: nil,
                createdAt: createdAt
            )
        }
    }

    private func localInferenceAttachments(from pending: [PendingAgentAttachment]) -> [LocalInferenceAttachment] {
        pending.map {
            LocalInferenceAttachment(
                fileName: $0.fileName,
                kind: $0.kind,
                extractedText: $0.payload.extractedText
            )
        }
    }

    private func localConversationHistory(from messages: [MobileAgentConversationMessage]) -> [LocalInferenceTurn] {
        messages.map {
            LocalInferenceTurn(
                role: $0.role,
                content: $0.content
            )
        }
    }

    private func makeConversationMessage(
        role: String,
        content: String,
        originalContent: String? = nil,
        sourceLanguage: String? = nil,
        targetLanguage: String? = nil,
        wasTranslated: Bool? = nil,
        deliveryStatus: String? = nil,
        provider: String?,
        thinkingMode: String?,
        attachments: [MobileAgentConversationAttachment]
    ) -> MobileAgentConversationMessage {
        MobileAgentConversationMessage(
            id: "local-message-\(UUID().uuidString)",
            role: role,
            content: content,
            originalContent: originalContent,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            wasTranslated: wasTranslated,
            deliveryStatus: deliveryStatus,
            provider: provider,
            thinkingMode: thinkingMode,
            messageKind: attachments.isEmpty ? "text" : "multimodal",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            attachments: attachments
        )
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard !conversationMessages.isEmpty else { return }

        let performScroll = {
            proxy.scrollTo("agent-thread-bottom-anchor", anchor: .bottom)
        }

        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.16)) {
                    performScroll()
                }
            } else {
                performScroll()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            performScroll()
        }
    }

    private func timestamp(for value: String) -> String {
        RotaryDateFormatting.messageTimestamp(value)
    }

    private func rotaryWorkflowElapsedLabel(seconds: Int) -> String {
        let safeSeconds = max(seconds, 0)
        let minutes = safeSeconds / 60
        let remainder = safeSeconds % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }

    private var agentHeaderDisplayName: String {
        let trimmed = agent.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Agent" }
        let firstWord = trimmed.split(separator: " ").first.map(String.init)
        return firstWord ?? trimmed
    }

    private func openAgentInfo() {
        composerFocused = false
        showingInfo = true
    }

    private var emptyConversationState: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 24)

            VStack(spacing: 10) {
                RotaryAvatarView(title: agent.name, size: 56)

                Text("No conversation history yet")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Send the first note to start the thread. Future messages will show up here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .frame(maxWidth: 300)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(RotaryTheme.incomingBubble, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
            )

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            composerFocused = false
        }
    }

    private var emptyConversationTitle: some View {
        RotaryConversationThreadHeader(
            title: agentHeaderDisplayName,
            avatarSize: 42,
            action: openAgentInfo
        )
        .accessibilityLabel("Open \(agent.name) info")
    }

    private var agentConversationHeader: some View {
        RotaryConversationThreadHeader(
            title: agentHeaderDisplayName,
            avatarSize: 44,
            action: openAgentInfo
        )
        .accessibilityLabel("Open \(agent.name) info")
    }

    private func mergeConversationMessages(
        remote: [MobileAgentConversationMessage],
        cached: [MobileAgentConversationMessage]
    ) -> [MobileAgentConversationMessage] {
        var mergedByID: [String: MobileAgentConversationMessage] = [:]

        for message in cached {
            mergedByID[message.id] = message
        }

        for message in remote {
            mergedByID[message.id] = message
        }

        return mergedByID.values.sorted { lhs, rhs in
            let lhsDate = RotaryDateFormatting.parse(lhs.createdAt) ?? .distantPast
            let rhsDate = RotaryDateFormatting.parse(rhs.createdAt) ?? .distantPast
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return lhs.id < rhs.id
        }
    }
}

private struct AgentInfoScreen: View {
    let agent: MobileAgent
    let relatedCalls: [MobileCall]
    let relatedThreads: [MobileThreadSummary]
    let conversation: MobileAgentConversationPayload?
    let messagesStore: MessagesStore
    let api: RotaryAPIClient
    @Bindable var voiceCoordinator: VoiceCoordinator
    let tokenProvider: RotaryTokenProvider

    @State private var selectedTab = AgentInfoTab.overview
    @State private var showingCallSheet = false
    @State private var showingMessageSheet = false
    @State private var seededPhoneNumber = ""
    @State private var callErrorMessage: String?

    private var documents: [MobileAgentConversationAttachment] {
        var seen = Set<String>()
        return (conversation?.messages ?? [])
            .flatMap(\.attachments)
            .filter { seen.insert($0.id).inserted }
    }

    private var tabItems: [RotaryProfileTabItem] {
        AgentInfoTab.allCases.map {
            RotaryProfileTabItem(id: $0.rawValue, title: $0.title, systemImage: $0.systemImage)
        }
    }

    private var activityItems: [AgentActivityItem] {
        let threadItems = relatedThreads.map {
            AgentActivityItem(
                id: "thread:\($0.contactId)",
                date: $0.lastMessageAt.flatMap(RotaryDateFormatting.parse),
                payload: .thread($0)
            )
        }

        let callItems = relatedCalls.map {
            AgentActivityItem(
                id: "call:\($0.id)",
                date: RotaryDateFormatting.parse($0.createdAt),
                payload: .call($0)
            )
        }

        return (threadItems + callItems).sorted {
            ($0.date ?? .distantPast) > ($1.date ?? .distantPast)
        }
    }

    private var overviewVoiceSummary: String {
        let modeText = (agent.thinkingMode ?? "balanced")
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()
        return "Voice: \(agent.voiceName). Replies are \(modeText), clear, and can be simplified if you ask."
    }

    private var overviewPersonalitySummary: String {
        "Just talk naturally. Rotary remembers your preferences over time and you can ask it anytime to change tone, language, or even its name."
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            RotaryProfileTabBar(
                items: tabItems,
                selectedID: Binding(
                    get: { selectedTab.rawValue },
                    set: { selectedTab = AgentInfoTab(rawValue: $0) ?? .overview }
                )
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 10)

            tabBody
        }
        .background(RotaryBackdrop())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingMessageSheet) {
            ProxyMessageSheet(
                fromNumber: agent.assignedPhoneNumber ?? "",
                initialToNumber: seededPhoneNumber,
                messagesStore: messagesStore
            )
        }
        .sheet(isPresented: $showingCallSheet) {
            ProxyCallSheet(
                fromNumber: agent.assignedPhoneNumber ?? "",
                initialPhoneNumber: seededPhoneNumber,
                startNativeCall: { phoneNumber in
                    guard ConnectivityMonitor.shared.isOnline else {
                        throw VoiceCoordinatorError.nativeVoiceUnavailable("You're offline. Reconnect to start a call.")
                    }
                    guard let lineId = agent.assignedLineId else {
                        throw VoiceCoordinatorError.missingLine
                    }
                    try await voiceCoordinator.startLineCall(
                        to: phoneNumber,
                        lineId: lineId,
                        handle: phoneNumber
                    )
                }
            )
        }
        .alert("Call Error", isPresented: Binding(
            get: { callErrorMessage != nil },
            set: { if !$0 { callErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(callErrorMessage ?? "")
        }
    }

    private var header: some View {
		VStack(spacing: 14) {
			RotaryProfileHero(
				title: agent.name,
				subtitle: nil,
				tertiaryText: nil
			) {
				HStack(alignment: .center, spacing: 14) {
					RotaryProfileActionButton(title: "Call", systemImage: "phone.fill") {
						Task { await callAgent() }
					}

					RotaryProfileActionButton(title: "Message", systemImage: "bubble.left.fill") {
						seededPhoneNumber = ""
						showingMessageSheet = true
					}
				}
				.frame(maxWidth: .infinity, alignment: .center)
				.padding(.horizontal, 8)
			}
		}
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var tabBody: some View {
        switch selectedTab {
        case .overview:
            ScrollView {
                VStack(spacing: 16) {
                    RotaryGlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                if let folderName = agent.folderName {
                                    RotaryAgentMetaPill(
                                        systemImage: "folder.fill",
                                        title: folderName,
                                        tint: .secondary
                                    )
                                }

                                Spacer(minLength: 0)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Voice and personality")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Text(overviewVoiceSummary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(overviewPersonalitySummary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if let latest = activityItems.first {
                        RotaryGlassCard {
                            agentActivityRow(latest)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        case .activity:
            List {
                if activityItems.isEmpty {
                    RotaryProfilePlaceholderCard(title: "No activity yet", systemImage: "clock")
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(activityItems) { item in
                        switch item.payload {
                        case let .thread(thread):
                            NavigationLink {
                                RotaryMessageThreadScreen(
                                    thread: thread,
                                    senderNumbers: [agent.assignedPhoneNumber].compactMap { $0 },
                                    ownerLine: agent.assignedPhoneNumber ?? "",
                                    store: messagesStore,
                                    startCall: { phoneNumber, _ in
                                        seededPhoneNumber = phoneNumber
                                        showingCallSheet = true
                                    }
                                )
                            } label: {
                                RotaryConversationSummaryRow(
                                    title: thread.contactName,
                                    preview: thread.preview,
                                    timestamp: thread.lastMessageAt.map(RotaryDateFormatting.listTimestamp) ?? "",
                                    avatarURL: nil,
                                    avatarSize: 50,
                                    isUnread: (thread.unreadCount ?? 0) > 0
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    Task {
                                        await messagesStore.performThreadAction(
                                            contactIds: [thread.contactId],
                                            action: (thread.unreadCount ?? 0) > 0 ? "mark_read" : "mark_unread"
                                        )
                                    }
                                } label: {
                                    Label((thread.unreadCount ?? 0) > 0 ? "Read" : "Unread", systemImage: (thread.unreadCount ?? 0) > 0 ? "envelope.open" : "envelope.badge")
                                }
                                .tint(RotaryTheme.accent)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task {
                                        await messagesStore.performThreadAction(contactIds: [thread.contactId], action: "move_to_deleted")
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    Task {
                                        await messagesStore.performThreadAction(contactIds: [thread.contactId], action: thread.isSpam == true ? "unmark_spam" : "mark_spam")
                                    }
                                } label: {
                                    Label(thread.isSpam == true ? "Inbox" : "Spam", systemImage: thread.isSpam == true ? "tray.and.arrow.down" : "exclamationmark.bubble")
                                }
                                .tint(thread.isSpam == true ? RotaryTheme.accent : RotaryTheme.warning)
                            }
                        case let .call(call):
                            NavigationLink {
                                CallDetailScreen(
                                    call: call,
                                    allCalls: relatedCalls,
                                    preferredSourceLine: agent.assignedPhoneNumber,
                                    startManualCall: { phoneNumber, _ in
                                        seededPhoneNumber = phoneNumber
                                        showingCallSheet = true
                                    },
                                    messagesStore: messagesStore,
                                    api: api,
                                    tokenProvider: tokenProvider
                                )
                            } label: {
                                agentCallRow(call)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        case .people:
            List {
                if relatedThreads.isEmpty {
                    RotaryProfilePlaceholderCard(title: "No people yet", systemImage: "person.2")
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(relatedThreads) { thread in
                        NavigationLink {
                            RotaryMessageThreadScreen(
                                thread: thread,
                                senderNumbers: [agent.assignedPhoneNumber].compactMap { $0 },
                                ownerLine: agent.assignedPhoneNumber ?? "",
                                store: messagesStore,
                                startCall: { phoneNumber, _ in
                                    seededPhoneNumber = phoneNumber
                                    showingCallSheet = true
                                }
                            )
                        } label: {
                            RotaryConversationSummaryRow(
                                title: thread.contactName,
                                preview: thread.preview,
                                timestamp: thread.lastMessageAt.map(RotaryDateFormatting.listTimestamp) ?? "",
                                avatarURL: nil,
                                avatarSize: 50,
                                isUnread: (thread.unreadCount ?? 0) > 0
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                Task {
                                    await messagesStore.performThreadAction(
                                        contactIds: [thread.contactId],
                                        action: (thread.unreadCount ?? 0) > 0 ? "mark_read" : "mark_unread"
                                    )
                                }
                            } label: {
                                Label((thread.unreadCount ?? 0) > 0 ? "Read" : "Unread", systemImage: (thread.unreadCount ?? 0) > 0 ? "envelope.open" : "envelope.badge")
                            }
                            .tint(RotaryTheme.accent)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    await messagesStore.performThreadAction(contactIds: [thread.contactId], action: "move_to_deleted")
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                seededPhoneNumber = thread.contactPhone ?? ""
                                showingMessageSheet = true
                            } label: {
                                Label("Send", systemImage: "paperplane.fill")
                            }
                            .tint(RotaryTheme.accent)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        case .assets:
            ScrollView {
                VStack(spacing: 12) {
                    if documents.isEmpty {
                        RotaryProfilePlaceholderCard(title: "No assets yet", systemImage: "folder")
                    } else {
                        ForEach(documents) { attachment in
                            RotaryGlassCard {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(RotaryTheme.softSurface)
                                        .frame(width: 46, height: 46)
                                        .overlay(
                                            Image(systemName: agentAssetSymbol(for: attachment))
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(RotaryTheme.accent)
                                        )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(attachment.fileName)
                                            .font(.body.weight(.semibold))
                                            .lineLimit(2)
                                        Text(attachment.extractedText?.nonEmptyTrimmed ?? attachment.attachmentKind.capitalized)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(3)
                                    }

                                    Spacer(minLength: 8)

                                    Text(RotaryDateFormatting.listTimestamp(attachment.createdAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private func agentActivityRow(_ item: AgentActivityItem) -> some View {
        switch item.payload {
        case let .thread(thread):
            return AnyView(
                RotaryConversationSummaryRow(
                    title: thread.contactName,
                    preview: thread.preview,
                    timestamp: thread.lastMessageAt.map(RotaryDateFormatting.listTimestamp) ?? "",
                    avatarURL: nil,
                    avatarSize: 50,
                    isUnread: (thread.unreadCount ?? 0) > 0
                )
            )
        case let .call(call):
            return AnyView(agentCallRow(call))
        }
    }

    private func agentCallRow(_ call: MobileCall) -> some View {
        let isMissed = agentCallIsMissed(call)
        let isUnreadVoicemail = agentCallIsUnreadVoicemail(call)

        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(RotaryTheme.incomingBubble)
                    .frame(width: 42, height: 42)

                Image(systemName: isMissed ? "phone.down.fill" : "phone.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isMissed ? RotaryTheme.destructive : RotaryTheme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(call.contactName.isEmpty ? (call.contactPhone ?? "Unknown number") : call.contactName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isMissed ? RotaryTheme.destructive : .primary)
                        .lineLimit(1)

                    if isUnreadVoicemail {
                        Circle()
                            .fill(RotaryTheme.accent)
                            .frame(width: 8, height: 8)
                    }

                    Spacer(minLength: 6)

                    Text(RotaryDateFormatting.listTimestamp(call.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(agentCallLocationAndStatus(call))
                    .font(.subheadline)
                    .foregroundStyle(isMissed ? RotaryTheme.destructive.opacity(0.85) : .secondary)
                    .lineLimit(1)

                if let preview = call.summary?.nonEmptyTrimmed ?? call.transcript?.nonEmptyTrimmed {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func callAgent() async {
        guard let phoneNumber = agent.assignedPhoneNumber else {
            callErrorMessage = "Rotary is still provisioning this agent’s line."
            return
        }
        guard ConnectivityMonitor.shared.isOnline else {
            callErrorMessage = "You're offline. Reconnect to start a call."
            return
        }

        do {
            try await voiceCoordinator.startOwnerCall(to: phoneNumber, handle: agent.name)
        } catch {
            callErrorMessage = error.localizedDescription
        }
    }
}

private enum AgentInfoTab: String, CaseIterable {
    case overview
    case activity
    case people
    case assets

    var title: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .overview:
            return "sparkles"
        case .activity:
            return "clock.fill"
        case .people:
            return "person.2.fill"
        case .assets:
            return "folder.fill"
        }
    }
}

private struct RotaryAgentMetaPill: View {
    let systemImage: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))

            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RotaryTheme.softSurface, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
        )
    }
}

private enum RotaryAgentWorkflowCardPresentation {
    case compact
    case expanded
}

private struct RotaryAgentWorkflowWidgetCard: View {
    let state: AgentWorkflowWidgetState
    let selectedCallOfferID: String?
    let onApprove: () -> Void
    let onModify: () -> Void
    let onStop: () -> Void
    let onDismiss: () -> Void
    let onSelectCallOffer: (AgentCallOffer) -> Void
    let onApplySteering: (String) -> Void
    let onCopyReport: (String) -> Void
    let presentation: RotaryAgentWorkflowCardPresentation
    let onOpenDetails: (() -> Void)?

    var body: some View {
        RotaryGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                header
                if presentation == .expanded {
                    VStack(alignment: .leading, spacing: 10) {
                        detailedContent
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        compactContent
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                }
                actions
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: headerSymbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(RotaryTheme.accent)
                .frame(width: 24, height: 24)
                .background(RotaryTheme.softSurface, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle)
                    .font(.subheadline.weight(.semibold))
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var detailedContent: some View {
        switch state {
        case let .awaitingApproval(mode, prompt, checklist, payload):
            Text(prompt)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(4)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(checklist, id: \.self) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(item)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let payload {
                draftPayloadBody(mode: mode, payload: payload)
            }
        case let .running(mode, _, stepIndex, steps, detail, payload):
            let total = max(steps.count, 1)
            let progress = min(max(Double(stepIndex + 1) / Double(total), 0), 1)

            ProgressView(value: progress)
                .tint(RotaryTheme.accent)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.primary)

            if stepIndex < steps.count {
                Text("Step \(stepIndex + 1) of \(steps.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let payload {
                runningPayloadBody(mode: mode, stepIndex: stepIndex, payload: payload)
            }
        case let .completed(mode, summary, details, payload):
            Text(summary)
                .font(.subheadline.weight(.semibold))

            if !(mode == .makeCall && payload != nil) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(details, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundStyle(RotaryTheme.accent)
                                .padding(.top, 6)
                            Text(item)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let payload {
                completionPayloadBody(mode: mode, payload: payload)
            }
        case let .failed(_, message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        case .cancelled:
            Text("Workflow cancelled. You can change the prompt and run it again.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private var compactContent: some View {
        switch state {
        case let .awaitingApproval(mode, prompt, checklist, payload):
            Text(prompt)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            if mode == .makeCall {
                HStack(spacing: 8) {
                    RotaryAgentMetaPill(
                        systemImage: "phone.badge.waveform",
                        title: "Ready",
                        tint: RotaryTheme.accent
                    )
                    if case let .makeCall(makeCallPayload)? = payload {
                        RotaryAgentMetaPill(
                            systemImage: "checklist",
                            title: "\(makeCallPayload.requiredQuestions.count) checks",
                            tint: .secondary
                        )
                    }
                }
            } else {
                Text("\(checklist.count) checks ready")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case let .running(mode, _, stepIndex, steps, detail, payload):
            let total = max(steps.count, 1)
            let progress = min(max(Double(stepIndex + 1) / Double(total), 0), 1)

            ProgressView(value: progress)
                .tint(RotaryTheme.accent)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            HStack(spacing: 8) {
                RotaryAgentMetaPill(
                    systemImage: "brain",
                    title: mode == .makeCall ? "Thinking" : "Working",
                    tint: RotaryTheme.accent
                )
                Text("Step \(min(stepIndex + 1, total))/\(total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if mode == .makeCall,
                   case let .makeCall(details)? = payload {
                    Spacer(minLength: 0)
                    Text(details.elapsedLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        case let .completed(mode, summary, details, payload):
            Text(summary)
                .font(.subheadline.weight(.semibold))

            if mode == .makeCall,
               case let .makeCall(callDetails)? = payload {
                let selectedOffer = callDetails.offers.first { $0.id == selectedCallOfferID }
                    ?? callDetails.offers.first { $0.id == callDetails.recommendedOfferID }

                if let selectedOffer {
                    Text("Top option: \(selectedOffer.providerName) at \(selectedOffer.priceText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    RotaryAgentMetaPill(
                        systemImage: "checkmark.seal.fill",
                        title: "Complete",
                        tint: RotaryTheme.callAccent
                    )
                    RotaryAgentMetaPill(
                        systemImage: "phone.connection.fill",
                        title: "\(callDetails.offers.count) offers",
                        tint: .secondary
                    )
                }
            } else if let firstDetail = details.first {
                Text(firstDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        case let .failed(_, message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        case .cancelled:
            Text("Workflow cancelled. You can change the prompt and run it again.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private func draftPayloadBody(mode: AgentComposerMode, payload: AgentWorkflowDraftPayload) -> some View {
        switch (mode, payload) {
        case let (.deepResearch, .deepResearch(details)):
            VStack(alignment: .leading, spacing: 8) {
                Text("Plan Preview")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(details.skeletonQueries, id: \.self) { query in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(RotaryTheme.softSurface.opacity(0.9))
                            .frame(width: 10, height: 10)
                        Text(query)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(details.approvalHint)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        case let (.makeCall, .makeCall(details)):
            VStack(alignment: .leading, spacing: 8) {
                Text("Context To Confirm")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(details.requiredQuestions) { question in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(question.title)
                                .font(.caption.weight(.semibold))
                            if question.isRequired {
                                Text("Required")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(RotaryTheme.warning.opacity(0.2), in: Capsule())
                            }
                        }
                        Text(question.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RotaryTheme.softSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func runningPayloadBody(mode: AgentComposerMode, stepIndex: Int, payload: AgentWorkflowRunningPayload) -> some View {
        switch (mode, payload) {
        case let (.deepResearch, .deepResearch(details)):
            VStack(alignment: .leading, spacing: 8) {
                Text(details.reasoningSnippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(details.sourceLabels, id: \.self) { label in
                            Text(label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(RotaryTheme.softSurface, in: Capsule())
                        }
                    }
                }
            }
        case let (.makeCall, .makeCall(details)):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(details.phaseTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(details.elapsedLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RotaryTheme.softSurface, in: Capsule(style: .continuous))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(details.participants) { participant in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(participantStateColor(participant.state))
                                    .frame(width: 7, height: 7)
                                Text(participant.name)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(participant.state.label)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(RotaryTheme.softSurface.opacity(0.82), in: Capsule(style: .continuous))
                        }
                    }
                }

                ForEach(Array(details.timeline.enumerated()), id: \.element.id) { index, event in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: event.symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(index <= stepIndex ? RotaryTheme.accent : .secondary)
                            .frame(width: 16, height: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                            if let subtitle = event.subtitle {
                                Text(subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !details.transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Live transcript")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(details.transcript.suffix(4)) { line in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(line.speaker)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    if let latency = line.latencyMs {
                                        Text("\(latency) ms")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if line.isTranslated {
                                        Image(systemName: "globe")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(RotaryTheme.accent)
                                    }
                                }
                                Text(line.text)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                if line.isTranslated,
                                   let original = line.originalText?.trimmingCharacters(in: .whitespacesAndNewlines),
                                   !original.isEmpty {
                                    Text(original)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(RotaryTheme.softSurface.opacity(0.76), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }

                if !details.steeringChoices.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Live steering")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(details.steeringChoices) { choice in
                                    Button {
                                        onApplySteering(choice.title)
                                    } label: {
                                        HStack(spacing: 6) {
                                            if choice.isRecommended {
                                                Image(systemName: "sparkles")
                                                    .font(.system(size: 10, weight: .bold))
                                            }
                                            Text(choice.title)
                                                .font(.caption2.weight(.semibold))
                                                .lineLimit(1)
                                        }
                                        .foregroundStyle(choice.isRecommended ? RotaryTheme.accent : .primary)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 7)
                                        .background(
                                            choice.isRecommended
                                                ? RotaryTheme.accent.opacity(0.14)
                                                : RotaryTheme.softSurface.opacity(0.88),
                                            in: Capsule(style: .continuous)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        if let steering = details.latestSteeringText,
                           !steering.isEmpty {
                            Text("Applied: \(steering)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func completionPayloadBody(mode: AgentComposerMode, payload: AgentWorkflowCompletionPayload) -> some View {
        switch (mode, payload) {
        case let (.deepResearch, .deepResearch(details)):
            VStack(alignment: .leading, spacing: 8) {
                Text("Report Outline")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(details.reportOutline, id: \.self) { line in
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(RotaryTheme.accent)
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case let (.makeCall, .makeCall(details)):
            VStack(alignment: .leading, spacing: 10) {
                Text("Comparable Offers")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(details.offers) { offer in
                    RotaryAgentCallOfferCard(
                        offer: offer,
                        isSelected: selectedCallOfferID == offer.id,
                        isRecommended: details.recommendedOfferID == offer.id,
                        onSelect: {
                            onSelectCallOffer(offer)
                        }
                    )
                }

                if !details.highlights.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Run highlights")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(details.highlights, id: \.self) { highlight in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 4, weight: .bold))
                                    .padding(.top, 6)
                                    .foregroundStyle(RotaryTheme.accent)
                                Text(highlight)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !details.metrics.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Metrics")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(details.metrics) { metric in
                            HStack(alignment: .top, spacing: 8) {
                                Text(metric.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(metric.value)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    if let detail = metric.detail {
                                        Text(detail)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                Button("Copy Run Report") {
                    onCopyReport(details.reportText)
                }
                .buttonStyle(RotaryAgentWorkflowSecondaryButtonStyle())
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch state {
            case .awaitingApproval:
                HStack(spacing: 8) {
                    Button("Approve", action: onApprove)
                        .buttonStyle(RotaryAgentWorkflowPrimaryButtonStyle())
                    Button("Modify", action: onModify)
                        .buttonStyle(RotaryAgentWorkflowSecondaryButtonStyle())
                    Button("Cancel", action: onStop)
                        .buttonStyle(RotaryAgentWorkflowSecondaryButtonStyle())
                }
            case .running:
                HStack(spacing: 8) {
                    Button("Stop", action: onStop)
                        .buttonStyle(RotaryAgentWorkflowPrimaryButtonStyle())
                }
            case .completed, .failed, .cancelled:
                HStack(spacing: 8) {
                    Button("Dismiss", action: onDismiss)
                        .buttonStyle(RotaryAgentWorkflowSecondaryButtonStyle())
                }
            case .idle:
                EmptyView()
            }

            if presentation == .compact,
               shouldShowOpenDetailsButton,
               let onOpenDetails {
                Button("Open Full Details") {
                    onOpenDetails()
                }
                .buttonStyle(RotaryAgentWorkflowSecondaryButtonStyle())
            }
        }
    }

    private var mode: AgentComposerMode? {
        switch state {
        case let .awaitingApproval(mode, _, _, _):
            return mode
        case let .running(mode, _, _, _, _, _):
            return mode
        case let .cancelled(mode):
            return mode
        case let .completed(mode, _, _, _):
            return mode
        case let .failed(mode, _):
            return mode
        case .idle:
            return nil
        }
    }

    private var shouldShowOpenDetailsButton: Bool {
        guard mode == .makeCall else { return false }
        switch state {
        case .awaitingApproval, .running, .completed:
            return true
        case .cancelled, .failed, .idle:
            return false
        }
    }

    private var headerTitle: String {
        switch state {
        case let .awaitingApproval(mode, _, _, _):
            return "\(mode.title) Ready"
        case let .running(mode, _, _, _, _, _):
            return mode.title
        case let .cancelled(mode):
            return "\(mode.title) Cancelled"
        case let .completed(mode, _, _, _):
            return "\(mode.title) Complete"
        case let .failed(mode, _):
            return "\(mode.title) Failed"
        case .idle:
            return "Workflow"
        }
    }

    private var headerSubtitle: String {
        switch state {
        case .awaitingApproval:
            if presentation == .compact, mode == .makeCall {
                return "Call setup is ready. Open full details to review context."
            }
            return "Review the plan before sending."
        case .running:
            if presentation == .compact, mode == .makeCall {
                return "Call workflow is thinking. Open full details for transcript and steering."
            }
            return "Rotary is working. Sending is temporarily locked."
        case .cancelled:
            return "No further actions were taken."
        case .completed:
            if presentation == .compact, mode == .makeCall {
                return "Summary ready. Open full details for offers, latency, and handoffs."
            }
            return "Results are ready below."
        case .failed:
            return "Try again with a narrower request."
        case .idle:
            return ""
        }
    }

    private var headerSymbol: String {
        switch state {
        case .awaitingApproval:
            return "doc.text.magnifyingglass"
        case .running:
            return "gearshape.2.fill"
        case .cancelled:
            return "xmark.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .idle:
            return "sparkles"
        }
    }

    private func participantStateColor(_ state: AgentWorkflowParticipantState) -> Color {
        switch state {
        case .standby:
            return .secondary.opacity(0.8)
        case .active:
            return .green.opacity(0.9)
        case .left:
            return RotaryTheme.warning
        }
    }
}

private struct RotaryAgentCallOfferCard: View {
    let offer: AgentCallOffer
    let isSelected: Bool
    let isRecommended: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(offer.providerName)
                        .font(.subheadline.weight(.semibold))
                    Text(offer.phoneNumber)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(offer.priceText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RotaryTheme.accent)
            }

            HStack(spacing: 8) {
                Label(offer.availabilityText, systemImage: "calendar")
                if let mapSummary = offer.mapSummary {
                    Label(mapSummary, systemImage: "map.fill")
                }
                if let weatherSummary = offer.weatherSummary {
                    Label(weatherSummary, systemImage: "cloud.sun.fill")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            Text(offer.notes)
                .font(.caption)
                .foregroundStyle(.secondary)

            if isSelected {
                Button("Selected \(offer.providerName)") {}
                    .buttonStyle(RotaryAgentWorkflowPrimaryButtonStyle())
                    .disabled(true)
            } else {
                Button("Choose \(offer.providerName)") {
                    onSelect()
                }
                .buttonStyle(RotaryAgentWorkflowSecondaryButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(RotaryTheme.softSurface.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isRecommended ? RotaryTheme.accent.opacity(0.55) : RotaryTheme.elevatedStroke,
                    lineWidth: 1
                )
        )
    }
}

private struct RotaryAgentWorkflowPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(.black.opacity(configuration.isPressed ? 0.7 : 0.82))
            .background(RotaryTheme.accent.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
    }
}

private struct RotaryAgentWorkflowSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(.primary.opacity(configuration.isPressed ? 0.72 : 0.9))
            .background(
                RotaryTheme.softSurface.opacity(configuration.isPressed ? 0.72 : 0.94),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
            )
    }
}

private struct AgentActivityItem: Identifiable {
    enum Payload {
        case thread(MobileThreadSummary)
        case call(MobileCall)
    }

    let id: String
    let date: Date?
    let payload: Payload
}

private func agentCallIsMissed(_ call: MobileCall) -> Bool {
    call.status.lowercased().contains("missed") || call.livePhase == .noAnswer
}

private func agentCallIsUnreadVoicemail(_ call: MobileCall) -> Bool {
    call.hasPlayableVoicemailRecording && call.readAt == nil
}

private func agentCallLocationAndStatus(_ call: MobileCall) -> String {
    let payload = call.intakePayload
    let location = payload["cnam_location"]?.stringValue
        ?? payload["caller_location"]?.stringValue
        ?? payload["location"]?.stringValue
        ?? agentAreaLabel(for: call.contactPhone ?? call.toNumber ?? call.fromNumber)
        ?? (call.contactPhone ?? call.toNumber ?? call.fromNumber ?? "Unknown number")

    let direction = agentCallDirectionLabel(call)

    if agentCallIsMissed(call) {
        let statusLabel = direction.isEmpty ? "Missed" : "Missed \(direction.lowercased())"
        return "\(location) • \(statusLabel)"
    }
    if call.hasPlayableVoicemailRecording {
        let statusLabel = direction.isEmpty ? "Voicemail" : "Voicemail \(direction.lowercased())"
        return "\(location) • \(statusLabel)"
    }
    if !direction.isEmpty {
        return "\(location) • \(direction)"
    }
    return location
}

private func agentCallDirectionLabel(_ call: MobileCall) -> String {
    let status = call.status.lowercased()
    if status.contains("outbound") {
        return "Outbound"
    }
    if status.contains("inbound") {
        return "Inbound"
    }
    if status.contains("voicemail") {
        return "Inbound"
    }
    return ""
}

private func agentAssetSymbol(for attachment: MobileAgentConversationAttachment) -> String {
    switch attachment.attachmentKind.lowercased() {
    case "image":
        return "photo"
    case "audio":
        return "waveform"
    case "pdf":
        return "doc.richtext"
    default:
        return "doc"
    }
}

private func agentAreaLabel(for phoneNumber: String?) -> String? {
    guard let phoneNumber else { return nil }
    let digits = phoneNumber.filter(\.isNumber)
    let normalizedDigits = digits.count == 11 && digits.first == "1" ? String(digits.dropFirst()) : digits
    guard normalizedDigits.count >= 10 else { return nil }

    let areaCode = String(normalizedDigits.prefix(3))
    let labels: [String: String] = [
        "213": "Los Angeles, CA",
        "310": "West Los Angeles, CA",
        "323": "Los Angeles, CA",
        "415": "San Francisco, CA",
        "424": "West Los Angeles, CA",
        "442": "North County, CA",
        "562": "Long Beach, CA",
        "619": "San Diego, CA",
        "626": "Pasadena, CA",
        "657": "Anaheim, CA",
        "714": "Anaheim, CA",
        "760": "Inland Empire, CA",
        "858": "San Diego, CA",
        "909": "Inland Empire, CA",
        "949": "Orange County, CA",
        "951": "Temecula, CA",
    ]

    return labels[areaCode]
}

private func preparePendingAttachment(from url: URL) async throws -> PendingAgentAttachment {
    let startedAccessing = url.startAccessingSecurityScopedResource()
    defer {
        if startedAccessing {
            url.stopAccessingSecurityScopedResource()
        }
    }

    let data = try Data(contentsOf: url)
    let fileName = url.lastPathComponent
    let fileExtension = url.pathExtension
    let mimeType = UTType(filenameExtension: fileExtension)?.preferredMIMEType ?? "application/octet-stream"
    let extractedText = try await extractAgentAttachmentText(data: data, fileName: fileName, mimeType: mimeType)

    return PendingAgentAttachment(
        payload: RotaryUploadAttachmentPayload(
            fileName: fileName,
            mimeType: mimeType,
            data: data,
            extractedText: extractedText
        ),
        fileName: fileName,
        kind: attachmentKindForMimeType(mimeType, fileName: fileName)
    )
}

private func attachmentKindForMimeType(_ mimeType: String, fileName: String) -> String {
    if mimeType.hasPrefix("image/") { return "image" }
    if mimeType.hasPrefix("audio/") { return "audio" }
    if mimeType == "application/pdf" || fileName.lowercased().hasSuffix(".pdf") { return "pdf" }
    return "file"
}

private func extractAgentAttachmentText(data: Data, fileName: String, mimeType: String) async throws -> String? {
    if mimeType == "application/pdf" || fileName.lowercased().hasSuffix(".pdf") {
        return extractPDFText(data: data)
    }

    if mimeType.hasPrefix("image/") {
        return try await recognizeImageText(data: data)
    }

    return nil
}

private func extractPDFText(data: Data) -> String? {
    guard let document = PDFDocument(data: data) else { return nil }
    return (0 ..< document.pageCount)
        .compactMap { document.page(at: $0)?.string }
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func recognizeImageText(data: Data) async throws -> String? {
    guard let image = UIImage(data: data)?.cgImage else { return nil }

    return try await withCheckedThrowingContinuation { continuation in
        let request = VNRecognizeTextRequest { request, error in
            if let error {
                continuation.resume(throwing: error)
                return
            }

            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let text = observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            continuation.resume(returning: text.isEmpty ? nil : text)
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            continuation.resume(throwing: error)
        }
    }
}

private extension String {
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
