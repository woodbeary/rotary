import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import UIKit
@preconcurrency import Vision

private struct PendingAgentAttachment: Identifiable {
    let id = UUID()
    let payload: RotaryUploadAttachmentPayload
    let fileName: String
    let kind: String
    var uploadedAttachment: MobileAgentConversationAttachment?
    var isUploading = false

    var detailText: String {
        if isUploading {
            return "Uploading…"
        }
        if uploadedAttachment != nil {
            return "Ready"
        }
        return kind.capitalized
    }
}

struct AgentConversationDetailScreen: View {
    let agent: MobileAgent
    let relatedCalls: [MobileCall]
    let relatedThreads: [MobileThreadSummary]
    let messagesStore: MessagesStore
    let api: RotaryAPIClient
    @Bindable var voiceCoordinator: VoiceCoordinator
    let tokenProvider: RotaryTokenProvider

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
    @State private var attachmentUploadTask: Task<Void, Never>?
    @FocusState private var composerFocused: Bool

    private var transcriptMessages: [RotaryConversationBubbleModel] {
        conversationMessages.map { message in
            RotaryConversationBubbleModel(
                id: message.id,
                direction: message.role == "user" ? .outbound : .inbound,
                text: message.content,
                timestamp: RotaryDateFormatting.messageTimestamp(message.createdAt),
                date: RotaryDateFormatting.parse(message.createdAt),
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

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RotaryBackdrop(onTap: { composerFocused = false })

                if !transcriptMessages.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                if isLoading {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.caption.weight(.semibold))
                                        Text("Refreshing in background")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RotaryTheme.softSurface,
                                        in: Capsule(style: .continuous)
                                    )
                                }

                                RotaryConversationTranscriptView(messages: transcriptMessages)
                                    .id(transcriptMessages.count)
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 86)
                            .padding(.bottom, 24)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            composerFocused = false
                        }
                        .onAppear {
                            scrollToBottom(proxy: proxy)
                        }
                        .onChange(of: conversationMessages.count) { _, _ in
                            scrollToBottom(proxy: proxy)
                        }
                    }
                } else {
                    ZStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                composerFocused = false
                            }

                        if isLoading {
                            ScrollView {
                                RotaryConversationSkeleton(rows: 6)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 96)
                                    .padding(.bottom, 24)
                            }
                            .scrollDisabled(true)
                        } else if let errorMessage, !errorMessage.isEmpty {
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
                                    Task { await loadConversation(forceRefresh: true) }
                                }
                                .buttonStyle(RotaryPrimaryButtonStyle())
                                .frame(maxWidth: 180)
                            }
                            .padding(.horizontal, 28)
                        }
                    }
                }
            }

            composer
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            RotaryConversationTopHeader(
                title: agent.name,
                subtitle: nil,
                avatarSize: 30,
                action: {
                    composerFocused = false
                    showingInfo = true
                }
            )
            .padding(.horizontal, 52)
            .padding(.top, 2)
            .padding(.bottom, 2)
        }
        .onDisappear {
            composerFocused = false
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if agent.assignedPhoneNumber != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    RotaryGlassIconButton(systemName: isCallingAgent ? "phone.badge.waveform" : "phone.fill") {
                        composerFocused = false
                        Task { await callAgent() }
                    }
                    .disabled(isCallingAgent)
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
        .task {
            await loadConversation()
        }
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

    private var composer: some View {
        VStack(spacing: 6) {
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
                placeholder: "Ask \(agent.name) anything",
                isWorking: isSending,
                isFocused: $composerFocused,
                onMic: nil,
                onSend: {
                    Task { await send() }
                }
            ) {
                Button("Photos", systemImage: "photo.on.rectangle") {
                    fileImportTypes = [.image]
                    showingFileImporter = true
                }
                Button("Audio", systemImage: "waveform") {
                    fileImportTypes = [.audio]
                    showingFileImporter = true
                }
                Button("Files", systemImage: "folder") {
                    fileImportTypes = [.pdf, .image, .audio, .plainText]
                    showingFileImporter = true
                }
            }
        }
    }

    @MainActor
    private func callAgent() async {
        guard let phoneNumber = agent.assignedPhoneNumber else {
            callErrorMessage = "Rotary is still provisioning this agent’s line."
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
    private func loadConversation(forceRefresh: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let payload = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.agentConversation(
                    token: token,
                    agentId: agent.id,
                    forceRefresh: forceRefresh
                )
            }
            conversationPayload = payload
            conversationMessages = payload.messages
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func send() async {
        let trimmedMessage = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty || !pendingAttachments.isEmpty else { return }

        if let attachmentUploadTask {
            await attachmentUploadTask.value
        }

        isSending = true
        defer { isSending = false }
        errorMessage = nil

        do {
            let attachmentIds = try await ensureUploadedPendingAttachments()

            _ = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.sendAgentConversationMessage(
                    token: token,
                    agentId: agent.id,
                    message: trimmedMessage.isEmpty ? nil : trimmedMessage,
                    attachmentIds: attachmentIds,
                    thinkingMode: agent.thinkingMode ?? "balanced"
                )
            }

            draft = ""
            pendingAttachments = []
            await loadConversation(forceRefresh: true)
        } catch {
            errorMessage = error.localizedDescription
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

            let payload = pendingAttachments[currentIndex].payload
            pendingAttachments[currentIndex].isUploading = true
            do {
                let result = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                    try await api.uploadAgentAttachment(
                        token: token,
                        agentId: agent.id,
                        payload: payload
                    )
                }
                guard let resultIndex = pendingAttachments.firstIndex(where: { $0.id == attachmentToken }) else {
                    continue
                }
                pendingAttachments[resultIndex].uploadedAttachment = result.attachment
                pendingAttachments[resultIndex].isUploading = false
                attachmentIDs.append(result.attachment.id)
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
        guard attachmentUploadTask == nil else { return }
        guard pendingAttachments.contains(where: { $0.uploadedAttachment == nil }) else { return }

        attachmentUploadTask = Task { @MainActor in
            defer { attachmentUploadTask = nil }

            while !Task.isCancelled {
                let needsUpload = pendingAttachments.contains {
                    $0.uploadedAttachment == nil && !$0.isUploading
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

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastId = conversationMessages.last?.id else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }

    private func timestamp(for value: String) -> String {
        RotaryDateFormatting.messageTimestamp(value)
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
        AgentInfoTab.allCases.map { RotaryProfileTabItem(id: $0.rawValue, title: $0.title) }
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
        .toolbar(.hidden, for: .tabBar)
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
                subtitle: agent.assignedPhoneNumber ?? "Provisioning line",
                tertiaryText: agent.folderName ?? "\(agent.voiceName) voice"
            ) {
                HStack(spacing: 18) {
                    RotaryProfileActionButton(title: "Call", systemImage: "phone.fill") {
                        Task { await callAgent() }
                    }

                    RotaryProfileActionButton(title: "Message", systemImage: "bubble.left.fill") {
                        seededPhoneNumber = ""
                        showingMessageSheet = true
                    }

                    RotaryProfileActionButton(title: "Line", systemImage: "waveform.path.ecg") {
                        selectedTab = .activity
                    }
                }
                .padding(.horizontal, 18)
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
                    RotaryProfileInfoCard(title: "Agent") {
                        RotaryProfileMetaRow(label: "status", value: agent.isActive ? "Active" : "Paused")
                        Divider()
                        RotaryProfileMetaRow(label: "voice", value: agent.voiceName)
                        Divider()
                        RotaryProfileMetaRow(label: "provider", value: agent.voiceProvider ?? "Unknown")
                        if let folderName = agent.folderName {
                            Divider()
                            RotaryProfileMetaRow(label: "folder", value: folderName)
                        }
                    }

                    RotaryProfileInfoCard(title: "Quick Actions") {
                        HStack(spacing: 12) {
                            Button {
                                seededPhoneNumber = ""
                                showingMessageSheet = true
                            } label: {
                                Label("Send as Agent", systemImage: "bubble.left.and.bubble.right.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(RotarySecondaryButtonStyle())

                            Button {
                                seededPhoneNumber = ""
                                showingCallSheet = true
                            } label: {
                                Label("Call From Line", systemImage: "phone.connection.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(RotarySecondaryButtonStyle())
                        }
                    }

                    if let latest = activityItems.first {
                        RotaryProfileInfoCard(title: "Latest Activity") {
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
    let status = call.status.lowercased()
    let isVoicemailLike = status.contains("voicemail")
        || call.recordingUrl != nil
        || call.summary != nil
        || call.transcript != nil
    return isVoicemailLike && call.readAt == nil
}

private func agentCallLocationAndStatus(_ call: MobileCall) -> String {
    let payload = call.intakePayload
    let location = payload["cnam_location"]?.stringValue
        ?? payload["caller_location"]?.stringValue
        ?? payload["location"]?.stringValue
        ?? agentAreaLabel(for: call.contactPhone ?? call.toNumber ?? call.fromNumber)
        ?? (call.contactPhone ?? call.toNumber ?? call.fromNumber ?? "Unknown number")

    if agentCallIsMissed(call) {
        return "\(location) • Missed"
    }
    return location
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
