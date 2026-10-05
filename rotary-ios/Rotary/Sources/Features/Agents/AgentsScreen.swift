import AVFoundation
import Observation
import SwiftUI

struct AgentsScreen: View {
    let bootstrap: MobileBootstrapReadyState
    let appModel: AppModel
    let api: RotaryAPIClient
    let messagesStore: MessagesStore
    let callsStore: CallsStore
    @Bindable var voiceCoordinator: VoiceCoordinator
    @Bindable var mutationDispatcher: RotaryMutationDispatcher
    let refresh: () -> Void
    let onActivityCountChange: ((Int) -> Void)?
    @Binding var pendingAgentID: String?

    @State private var selectedFolderId: String?
    @State private var showingCreateAgent = false
    @State private var showingCreateFolder = false
    @State private var searchText = ""
    @State private var isEditing = false
    @State private var selectedAgentIDs = Set<String>()
    @State private var renamingFolder: MobileAgentFolderSummary?
    @State private var prefetchedConversations: [String: MobileAgentConversationPayload] = [:]
    @State private var prefetchingAgentIDs = Set<String>()
    @FocusState private var isSearchFieldFocused: Bool
    @State private var navigationPath = NavigationPath()

    init(
        bootstrap: MobileBootstrapReadyState,
        appModel: AppModel,
        api: RotaryAPIClient,
        messagesStore: MessagesStore,
        callsStore: CallsStore,
        voiceCoordinator: VoiceCoordinator,
        mutationDispatcher: RotaryMutationDispatcher,
        refresh: @escaping () -> Void,
        onActivityCountChange: ((Int) -> Void)? = nil,
        pendingAgentID: Binding<String?>
    ) {
        self.bootstrap = bootstrap
        self.appModel = appModel
        self.api = api
        self.messagesStore = messagesStore
        self.callsStore = callsStore
        self.voiceCoordinator = voiceCoordinator
        self.mutationDispatcher = mutationDispatcher
        self.refresh = refresh
        self.onActivityCountChange = onActivityCountChange
        _pendingAgentID = pendingAgentID
    }

    private var visibleAgents: [MobileAgent] {
        bootstrap.agents.filter { !isHiddenPlaceholderAgent($0) }
    }

    private var filteredAgents: [MobileAgent] {
        let base = selectedFolderId == nil
            ? visibleAgents
            : visibleAgents.filter { $0.folderId == selectedFolderId }

        guard !searchText.isEmpty else { return base }
        let query = searchText.lowercased()
        return base.filter { agent in
            [
                agent.name.lowercased(),
                agent.assignedPhoneNumber?.lowercased(),
                agent.folderName?.lowercased(),
                latestPreview(for: agent).lowercased(),
            ]
            .compactMap { $0 }
            .contains(where: { $0.contains(query) })
        }
    }

    private var currentFolder: MobileAgentFolderSummary? {
        guard let selectedFolderId else { return nil }
        return (bootstrap.folders ?? []).first(where: { $0.id == selectedFolderId })
    }

    private var tokenProvider: RotaryTokenProvider {
        { forceRefresh in
            try await appModel.token(forceRefresh: forceRefresh)
        }
    }

    private var conversationPrefetchSignature: String {
        filteredAgents
            .prefix(4)
            .map(\.id)
            .joined(separator: "|")
    }

    private var agentActivityCount: Int {
        let assignedNumbers = Set(visibleAgents.compactMap { normalizedPhone($0.assignedPhoneNumber) })
        guard !assignedNumbers.isEmpty else { return 0 }

        return messagesStore.threads
            .filter { thread in
                guard let preferredNumber = normalizedPhone(thread.preferredFromNumber) else {
                    return false
                }
                return thread.isDeleted != true
                    && thread.isSpam != true
                    && assignedNumbers.contains(preferredNumber)
            }
            .reduce(0) { partialResult, thread in
                partialResult + max(thread.unreadCount ?? 0, 0)
            }
    }

    private func isHiddenPlaceholderAgent(_ agent: MobileAgent) -> Bool {
        let signature = "\(agent.name) \(agent.slug) \(agent.voiceName)".lowercased()
        return signature.contains("nullvoice")
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                RotaryBackdrop(onTap: { RotaryKeyboard.dismiss() })

                VStack(spacing: 0) {
                    if RotaryDebugFlags.forceSkeletonPlaceholders {
                        RotarySkeletonList(rows: 6)
                            .padding(.top, 4)
                    } else if filteredAgents.isEmpty {
                        emptyState
                    } else {
                        List(filteredAgents) { agent in
                            if isEditing {
                                editableRow(agent)
                            } else {
                                NavigationLink(value: agent.id) {
                                    RotaryConversationSummaryRow(
                                        title: agent.name,
                                        preview: latestPreview(for: agent),
                                        timestamp: latestTimestampText(for: agent),
                                        avatarURL: nil,
                                        avatarSize: 50,
                                        isUnread: false,
                                        showsPreviewSkeleton: false,
                                        previewSystemImage: previewSymbol(for: agent)
                                    )
                                }
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                        .scrollDismissesKeyboard(.interactively)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isEditing {
                    agentsEditingBar
                } else {
                    agentsBottomBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbar(.visible, for: .tabBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        RotaryHaptics.selection()
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isEditing.toggle()
                            if !isEditing {
                                selectedAgentIDs.removeAll()
                            }
                        }
                    } label: {
                        Text(isEditing ? "Done" : "Edit")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 15)
                            .frame(minWidth: 68, minHeight: 38)
                            .background(toolbarControlFill, in: Capsule(style: .continuous))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(toolbarControlStroke, lineWidth: 0.9)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 2)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section("Folders") {
                            Button {
                                RotaryHaptics.selection()
                                selectedFolderId = nil
                            } label: {
                                Label("All Agents", systemImage: "person.2.fill")
                            }

                            ForEach(bootstrap.folders ?? []) { folder in
                                Button {
                                    RotaryHaptics.selection()
                                    selectedFolderId = folder.id
                                } label: {
                                    Label(folder.name, systemImage: "folder.fill")
                                }
                            }
                        }

                        Section("Create") {
                            Button("New Agent", systemImage: "person.badge.plus") {
                                showingCreateAgent = true
                            }

                            Button("New Folder", systemImage: "folder.badge.plus") {
                                showingCreateFolder = true
                            }
                        }

                        if let currentFolder {
                            Section("Folder") {
                                Button("Rename Current Folder", systemImage: "pencil") {
                                    beginRenaming(currentFolder)
                                }
                            }
                        }
                        if isEditing {
                            Section("Selection") {
                                Button("Select All", systemImage: "checkmark.circle") {
                                    selectedAgentIDs = Set(filteredAgents.map(\.id))
                                }
                                Button("Clear Selection", systemImage: "circle") {
                                    selectedAgentIDs.removeAll()
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(RotaryTheme.accent)
                            .frame(width: 44, height: 38)
                            .background(toolbarControlFill, in: Capsule(style: .continuous))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(toolbarControlStroke, lineWidth: 0.9)
                            )
                            .accessibilityLabel("Agent settings")
                    }
                }
            }
            .sheet(isPresented: $showingCreateAgent) {
                CreateAgentSheet(appModel: appModel, onCreated: refresh)
            }
            .sheet(isPresented: $showingCreateFolder) {
                CreateFolderSheet(appModel: appModel, onCreated: refresh)
            }
            .sheet(item: $renamingFolder) { folder in
                RenameFolderSheet(appModel: appModel, folder: folder, onSaved: refresh)
            }
            .navigationDestination(for: String.self) { agentID in
                if let agent = agentRecord(for: agentID) {
                    agentConversationDestination(for: agent)
                } else {
                    RotaryAgentUnavailableScreen()
                }
            }
        }
        .task(id: conversationPrefetchSignature) {
            await prefetchLikelyAgentConversations()
        }
        .task {
            await appModel.prewarmVoicePresets()
            publishActivityCount()
        }
        .onChange(of: agentActivityCount) { _, _ in
            publishActivityCount()
        }
        .task(id: pendingAgentID) {
            await openPendingAgentIfNeeded()
        }
    }

    private var agentsBottomBar: some View {
        HStack(spacing: 10) {
            RotarySearchField(
                text: $searchText,
                prompt: "Search agents",
                onMic: {
                    RotaryHaptics.selection()
                    isSearchFieldFocused = true
                },
                isFocused: $isSearchFieldFocused
            )

            Button {
                RotaryHaptics.selection()
                showingCreateAgent = true
            } label: {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 46, height: 46)
                    .background(toolbarControlFill, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(toolbarControlStroke, lineWidth: 0.9)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Create agent")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var agentsEditingBar: some View {
        HStack(spacing: 10) {
            RotaryGlassTextButton(title: "Select All") {
                selectedAgentIDs = Set(filteredAgents.map(\.id))
            }

            RotaryGlassTextButton(title: "Clear") {
                selectedAgentIDs.removeAll()
            }

            Text("\(selectedAgentIDs.count) selected")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func folderChip(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard !isActive else { return }
            RotaryHaptics.selection()
            action()
        } label: {
            RotaryPill(text: title, active: isActive)
        }
        .buttonStyle(.plain)
    }

    private func editableRow(_ agent: MobileAgent) -> some View {
        Button {
            RotaryHaptics.selection()
            if selectedAgentIDs.contains(agent.id) {
                selectedAgentIDs.remove(agent.id)
            } else {
                selectedAgentIDs.insert(agent.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedAgentIDs.contains(agent.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(selectedAgentIDs.contains(agent.id) ? RotaryTheme.accent : .secondary)

                RotaryConversationSummaryRow(
                    title: agent.name,
                    preview: latestPreview(for: agent),
                    timestamp: latestTimestampText(for: agent),
                    avatarURL: nil,
                    avatarSize: 50,
                    isUnread: false,
                    showsPreviewSkeleton: false,
                    previewSystemImage: previewSymbol(for: agent)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 24)

            VStack(spacing: 10) {
                Circle()
                    .fill(RotaryTheme.softSurface)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "person.2")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.secondary)
                    )

                Text(searchText.isEmpty ? "No agents yet" : "No matching agents")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(searchText.isEmpty ? "Create an agent to get started." : "Try a different search or folder.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                if searchText.isEmpty {
                    Button("Create Agent") {
                        showingCreateAgent = true
                    }
                    .buttonStyle(RotaryPrimaryButtonStyle())
                    .frame(maxWidth: 220)
                    .padding(.top, 6)
                }
            }
            .frame(maxWidth: 300)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(RotaryTheme.secondarySurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
            )

            Spacer(minLength: 24)
        }
        .padding(.horizontal, 24)
    }

    private func latestPreview(for agent: MobileAgent) -> String {
        if let preview = conversationPreview(for: agent) {
            return preview
        }
        if let thread = relatedThreads(for: agent).first {
            return normalizedPreviewText(thread.preview)
        }
        if let call = relatedCalls(for: agent).first {
            return normalizedPreviewText(call.summary ?? call.transcript ?? call.contactPhone ?? "Recent phone activity")
        }
        return "Ready"
    }

    private func latestTimestampText(for agent: MobileAgent) -> String {
        let conversationDate = prefetchedConversations[agent.id].flatMap(latestConversationDate)
        let threadDate = relatedThreads(for: agent).compactMap { $0.lastMessageAt }.compactMap(parseDate).max()
        let callDate = relatedCalls(for: agent).compactMap { parseDate($0.createdAt) }.max()
        let date = [conversationDate, threadDate, callDate].compactMap { $0 }.max()
        guard let date else { return "" }
        return RotaryDateFormatting.relativeTimestamp(for: date)
    }

    private func previewSymbol(for agent: MobileAgent) -> String? {
        if conversationPreview(for: agent) != nil {
            return nil
        }

        if relatedThreads(for: agent).first != nil || relatedCalls(for: agent).first != nil {
            return nil
        }

        return "sparkles"
    }

    private func agentRecord(for agentID: String) -> MobileAgent? {
        visibleAgents.first { $0.id == agentID }
    }

    @ViewBuilder
    private func agentConversationDestination(for agent: MobileAgent) -> some View {
        AgentConversationDetailScreen(
            agent: agent,
            relatedCalls: relatedCalls(for: agent),
            relatedThreads: relatedThreads(for: agent),
            messagesStore: messagesStore,
            api: api,
            voiceCoordinator: voiceCoordinator,
            tokenProvider: { forceRefresh in
                try await appModel.token(forceRefresh: forceRefresh)
            },
            mutationDispatcher: mutationDispatcher,
            inferenceModeStore: appModel.inferenceModeStore,
            initialConversation: prefetchedConversations[agent.id],
            onConversationLoaded: { payload in
                prefetchedConversations[agent.id] = payload
            }
        )
    }

    private func conversationPreview(for agent: MobileAgent) -> String? {
        guard let conversation = prefetchedConversations[agent.id] else {
            return nil
        }

        guard let lastMessage = conversation.messages.last else {
            return nil
        }

        let content = lastMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !content.isEmpty {
            return normalizedPreviewText(content)
        }

        if let firstAttachment = lastMessage.attachments.first {
            return normalizedPreviewText(firstAttachment.fileName)
        }

        return nil
    }

    private func normalizedPreviewText(_ value: String) -> String {
        rotarySanitizedConversationPreview(value)
    }

    private func latestConversationDate(for payload: MobileAgentConversationPayload) -> Date? {
        if let messageDate = payload.messages.compactMap({ parseDate($0.createdAt) }).max() {
            return messageDate
        }
        return parseDate(payload.conversation.lastActivityAt)
    }

    private func relatedCalls(for agent: MobileAgent) -> [MobileCall] {
        callsStore.relatedCalls(for: agent)
    }

    private func relatedThreads(for agent: MobileAgent) -> [MobileThreadSummary] {
        messagesStore.relatedThreads(forPreferredFromNumber: agent.assignedPhoneNumber)
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }

    private func normalizedPhone(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var toolbarControlFill: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.17, green: 0.18, blue: 0.22, alpha: 0.92)
            }
            return UIColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 0.94)
        })
    }

    private var toolbarControlStroke: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor.separator.withAlphaComponent(0.24)
            }
            return UIColor.separator.withAlphaComponent(0.10)
        })
    }

    private func publishActivityCount() {
        onActivityCountChange?(agentActivityCount)
    }

    private func openPendingAgentIfNeeded() async {
        guard let pendingAgentID = pendingAgentID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !pendingAgentID.isEmpty else {
            return
        }

        guard let agent = agentRecord(for: pendingAgentID) else {
            self.pendingAgentID = nil
            return
        }

        selectedFolderId = agent.folderId
        searchText = ""
        navigationPath = NavigationPath()
        navigationPath.append(agent.id)
        self.pendingAgentID = nil
    }

    private func nextFolderName() -> String {
        let existingNames = Set((bootstrap.folders ?? []).map { $0.name.lowercased() })
        if !existingNames.contains("new folder") {
            return "New Folder"
        }

        var index = 2
        while existingNames.contains("new folder \(index)") {
            index += 1
        }
        return "New Folder \(index)"
    }

    private func beginRenaming(_ folder: MobileAgentFolderSummary) {
        renamingFolder = folder
        RotaryHaptics.selection()
    }

    @MainActor
    private func prefetchLikelyAgentConversations() async {
        let candidates = Array(filteredAgents.prefix(searchText.isEmpty ? 4 : 6))
        guard !candidates.isEmpty else { return }

        let uncached = candidates.filter { prefetchedConversations[$0.id] == nil }
        guard !uncached.isEmpty else { return }

        prefetchingAgentIDs.formUnion(uncached.map(\.id))
        let tokenProvider = tokenProvider
        let api = api

        await withTaskGroup(of: (String, MobileAgentConversationPayload?).self) { group in
            for agent in uncached {
                group.addTask {
                    do {
                        let payload = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                            try await api.agentConversation(
                                token: token,
                                agentId: agent.id,
                                forceRefresh: false
                            )
                        }
                        return (agent.id, payload)
                    } catch {
                        return (agent.id, nil)
                    }
                }
            }

            for await (agentID, payload) in group {
                if let payload {
                    prefetchedConversations[agentID] = payload
                }
                prefetchingAgentIDs.remove(agentID)
            }
        }
    }
}

private struct RotaryAgentUnavailableScreen: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Agent unavailable")
                .font(.headline)
            Text("Rotary could not find that agent conversation yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(RotaryBackdrop())
    }
}

struct CreateFolderSheet: View {
    @Environment(\.dismiss) private var dismiss

    let appModel: AppModel
    let onCreated: () -> Void

    @State private var name = ""
    @State private var folderDescription = ""
    @State private var color = "blue"
    @State private var isWorking = false
    @State private var errorMessage: String?

    init(appModel: AppModel, onCreated: @escaping () -> Void = {}) {
        self.appModel = appModel
        self.onCreated = onCreated
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Folder Name") {
                    TextField("Support", text: $name)
                }

                Section("Description") {
                    TextField("What belongs here?", text: $folderDescription, axis: .vertical)
                        .lineLimit(2 ... 5)
                }

                Section("Color") {
                    Picker("Color", selection: $color) {
                        ForEach(["blue", "green", "orange", "pink"], id: \.self) { option in
                            Text(option.capitalized).tag(option)
                        }
                    }
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(RotaryBackdrop(onTap: { RotaryKeyboard.dismiss() }))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isWorking ? "Saving" : "Save") {
                        Task { await submit() }
                    }
                    .disabled(isWorking || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func submit() async {
        isWorking = true
        defer { isWorking = false }

        do {
            try await appModel.createFolder(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                description: folderDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : folderDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                color: color
            )
            onCreated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct RenameFolderSheet: View {
    @Environment(\.dismiss) private var dismiss

    let appModel: AppModel
    let folder: MobileAgentFolderSummary
    let onSaved: () -> Void

    @State private var name: String
    @State private var isWorking = false
    @State private var errorMessage: String?

    init(
        appModel: AppModel,
        folder: MobileAgentFolderSummary,
        onSaved: @escaping () -> Void = {}
    ) {
        self.appModel = appModel
        self.folder = folder
        self.onSaved = onSaved
        _name = State(initialValue: folder.name)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Folder Name") {
                    TextField("Folder", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(RotaryBackdrop(onTap: { RotaryKeyboard.dismiss() }))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isWorking ? "Saving" : "Save") {
                        Task { await save() }
                    }
                    .disabled(isWorking || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() async {
        isWorking = true
        defer { isWorking = false }

        do {
            try await appModel.renameFolder(
                id: folder.id,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            onSaved()
            RotaryHaptics.selection()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            RotaryHaptics.error()
        }
    }
}

struct CreateAgentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let appModel: AppModel
    let onCreated: () -> Void

    @State private var voiceOptions: [MobileVoicePreset] = []
    @State private var selectedVoiceId: String?
    @State private var selectedVoiceName = ""
    @State private var isLoadingVoices = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var previewPlayer = VoicePreviewPlayer()

    init(appModel: AppModel, onCreated: @escaping () -> Void = {}) {
        self.appModel = appModel
        self.onCreated = onCreated
    }

    private var curatedVoiceOptions: [MobileVoicePreset] {
        let preferred = eligibleElevenLabsVoices
        let sorted = preferred.sorted { lhs, rhs in
            let lhsPriority = lhs.rotaryRealtimePriority
            let rhsPriority = rhs.rotaryRealtimePriority
            if lhsPriority != rhsPriority {
                return lhsPriority > rhsPriority
            }
            switch (lhs.previewUrl == nil, rhs.previewUrl == nil) {
            case (false, true): return true
            case (true, false): return false
            default: return lhs.name < rhs.name
            }
        }
        return Array(sorted.prefix(10))
    }

    private var eligibleElevenLabsVoices: [MobileVoicePreset] {
        voiceOptions.filter(\.rotaryV3ExpressiveEligible)
    }

    private var voiceEligibilityMessage: String {
        if let explicitError = errorMessage, !explicitError.isEmpty {
            return explicitError
        }

        guard !voiceOptions.isEmpty else {
            return isLoadingVoices ? "" : "Rotary is loading eligible ElevenLabs voices."
        }

        if displayVoiceOptions.isEmpty {
            return voiceOptions.first?.rotaryVoiceEligibilityMessage
                ?? "Rotary requires an ElevenLabs v3 expressive voice before creating an agent."
        }

        return ""
    }

    private var displayVoiceOptions: [MobileVoicePreset] {
        return curatedVoiceOptions
    }

    private var resolvedAgentName: String {
        let base = selectedVoiceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty {
            return "Rotary Assistant"
        }
        return "\(base) Assistant"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Popular Voices") {
                    if displayVoiceOptions.isEmpty {
                        Text(voiceEligibilityMessage.isEmpty ? "Rotary requires an ElevenLabs v3 expressive voice before creating an agent." : voiceEligibilityMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(displayVoiceOptions, id: \.id) { voice in
                            AgentVoiceOptionRow(
                                voice: voice,
                                isSelected: selectedVoiceId == voice.id,
                                isPlaying: previewPlayer.isPlaying(voice.id),
                                onPreviewToggle: { previewPlayer.toggle(for: voice) },
                                onSelect: {
                                    selectedVoiceId = voice.id
                                    selectedVoiceName = voice.name
                                }
                            )
                        }
                    }

                    if isLoadingVoices {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Refreshing voice list")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(RotaryBackdrop(onTap: { RotaryKeyboard.dismiss() }))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isWorking ? "Creating" : "Create") {
                        Task { await submit() }
                    }
                    .disabled(isWorking || selectedVoiceName.isEmpty || selectedVoiceId == nil || displayVoiceOptions.isEmpty)
                }
            }
        }
        .task {
            let cached = appModel.cachedVoicePresetsSnapshot
            if !cached.isEmpty {
                applyVoiceOptions(cached)
            } else {
                await loadVoices(showLoading: true)
            }

            // Refresh in the background so voice changes propagate without blocking sheet open.
            Task {
                await loadVoices(showLoading: false)
            }
        }
        .onDisappear {
            previewPlayer.stop()
        }
    }

    private func loadVoices(showLoading: Bool) async {
        if showLoading {
            isLoadingVoices = true
        }
        defer {
            if showLoading {
                isLoadingVoices = false
            }
        }

        do {
            let voices = try await appModel.refreshVoicePresets()
            applyVoiceOptions(voices)
        } catch {
            if voiceOptions.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func applyVoiceOptions(_ voices: [MobileVoicePreset]) {
        voiceOptions = voices
        guard let firstVoice = displayVoiceOptions.first else {
            selectedVoiceId = nil
            selectedVoiceName = ""
            return
        }

        if !displayVoiceOptions.contains(where: { $0.id == selectedVoiceId }) {
            selectedVoiceId = firstVoice.id
            selectedVoiceName = firstVoice.name
            return
        }

        if selectedVoiceName.isEmpty,
           let currentVoice = displayVoiceOptions.first(where: { $0.id == selectedVoiceId }) {
            selectedVoiceName = currentVoice.name
        }
    }

    private func submit() async {
        guard let selectedVoice = displayVoiceOptions.first(where: { $0.id == selectedVoiceId }),
              selectedVoice.rotaryV3ExpressiveEligible else {
            errorMessage = displayVoiceOptions.isEmpty
                ? "Rotary requires an ElevenLabs v3 expressive voice before creating an agent."
                : "Select an eligible ElevenLabs v3 expressive voice before creating an agent."
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            try await appModel.createFirstAgent(
                name: resolvedAgentName,
                purpose: "Everyday",
                voiceName: selectedVoice.name,
                voiceProfileId: selectedVoice.id,
                thinkingMode: "balanced",
                folderId: nil
            )
            onCreated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AgentVoiceOptionRow: View {
    let voice: MobileVoicePreset
    let isSelected: Bool
    let isPlaying: Bool
    let onPreviewToggle: () -> Void
    let onSelect: () -> Void

    private var labelValues: [String] {
        let keys = ["accent", "gender", "age", "use_case"]
        return keys.compactMap { key in
            guard let value = voice.labels?[key], !value.isEmpty else { return nil }
            return value.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPreviewToggle) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RotaryTheme.accent)
                    .frame(width: 36, height: 36)
                    .background(RotaryTheme.elevatedSurface, in: Circle())
            }
            .buttonStyle(.plain)

            Button(action: onSelect) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(voice.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)

                        if let description = voice.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        if !labelValues.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(labelValues, id: \.self) { label in
                                        Text(label)
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(RotaryTheme.softSurface, in: Capsule())
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 12)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? RotaryTheme.accent : Color.secondary)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

@MainActor
@Observable
private final class VoicePreviewPlayer {
    private var player: AVPlayer?
    private(set) var activeVoiceID: String?

    func isPlaying(_ voiceID: String) -> Bool {
        activeVoiceID == voiceID
    }

    func toggle(for voice: MobileVoicePreset) {
        guard let previewUrl = voice.previewUrl, let url = URL(string: previewUrl) else {
            return
        }

        if activeVoiceID == voice.id {
            stop()
            return
        }

        stop()
        let player = AVPlayer(url: url)
        self.player = player
        activeVoiceID = voice.id
        player.play()
    }

    func stop() {
        player?.pause()
        player = nil
        activeVoiceID = nil
    }
}

struct ProxyMessageSheet: View {
    @Environment(\.dismiss) private var dismiss

    let fromNumber: String
    let initialToNumber: String
    let messagesStore: MessagesStore

    @State private var toNumber = ""
    @State private var message = ""
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            List {
                Section("To") {
                    TextField("Phone number", text: $toNumber)
                        .keyboardType(.phonePad)
                }

                Section("From") {
                    Text(fromNumber)
                        .foregroundStyle(.secondary)
                }

                Section("Message") {
                    TextField("Message", text: $message, axis: .vertical)
                        .lineLimit(3 ... 8)
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(RotaryBackdrop(onTap: { RotaryKeyboard.dismiss() }))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isWorking ? "Sending" : "Send") {
                        Task { await send() }
                    }
                    .disabled(isWorking || fromNumber.isEmpty || toNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .task {
            if toNumber.isEmpty {
                toNumber = initialToNumber
            }
        }
    }

    private func send() async {
        let destination = toNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let outgoing = message.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !destination.isEmpty else {
            errorMessage = "Enter a phone number first."
            return
        }

        guard !outgoing.isEmpty else {
            errorMessage = "Type a message first."
            return
        }

        isWorking = true
        Task {
            await messagesStore.sendMessage(
                to: destination,
                contactName: destination,
                contactId: nil,
                fromNumber: fromNumber,
                message: outgoing
            )
        }
        dismiss()
    }
}

struct ProxyCallSheet: View {
    @Environment(\.dismiss) private var dismiss

    let fromNumber: String
    let initialPhoneNumber: String
    let startNativeCall: (_ phoneNumber: String) async throws -> Void

    @State private var phoneNumber = ""
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            List {
                Section("To") {
                    TextField("Phone number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }

                Section("From") {
                    Text(fromNumber)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(RotaryBackdrop(onTap: { RotaryKeyboard.dismiss() }))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isWorking ? "Starting" : "Call") {
                        Task { await startCall() }
                    }
                    .disabled(isWorking || fromNumber.isEmpty || phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .task {
            if phoneNumber.isEmpty {
                phoneNumber = initialPhoneNumber
            }
        }
    }

    private func startCall() async {
        isWorking = true
        defer { isWorking = false }

        do {
            let destination = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !destination.isEmpty else {
                errorMessage = "Enter a phone number first."
                return
            }

            try await startNativeCall(destination)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
