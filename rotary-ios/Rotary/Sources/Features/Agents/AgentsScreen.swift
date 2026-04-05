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
    let refresh: () -> Void

    @State private var selectedFolderId: String?
    @State private var showingCreateAgent = false
    @State private var showingCreateFolder = false
    @State private var searchText = ""
    @State private var renamingFolder: MobileAgentFolderSummary?

    private var filteredAgents: [MobileAgent] {
        let base = selectedFolderId == nil
            ? bootstrap.agents
            : bootstrap.agents.filter { $0.folderId == selectedFolderId }

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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                agentsHeader

                ZStack {
                    RotaryBackdrop(onTap: { RotaryKeyboard.dismiss() })

                    if RotaryDebugFlags.forceSkeletonPlaceholders {
                        RotarySkeletonList(rows: 6)
                            .padding(.top, 4)
                    } else if filteredAgents.isEmpty {
                        emptyState
                    } else {
                        List(filteredAgents) { agent in
                            NavigationLink {
                                AgentConversationDetailScreen(
                                    agent: agent,
                                    relatedCalls: relatedCalls(for: agent),
                                    relatedThreads: relatedThreads(for: agent),
                                    messagesStore: messagesStore,
                                    api: api,
                                    voiceCoordinator: voiceCoordinator,
                                    tokenProvider: { forceRefresh in
                                        try await appModel.token(forceRefresh: forceRefresh)
                                    }
                                )
                            } label: {
                                RotaryConversationSummaryRow(
                                    title: agent.name,
                                    preview: latestPreview(for: agent),
                                    timestamp: latestTimestampText(for: agent),
                                    avatarURL: nil,
                                    avatarSize: 50,
                                    isUnread: false
                                )
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .scrollDismissesKeyboard(.interactively)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
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
                    } label: {
                        RotaryGlassMenuChip(
                            systemName: currentFolder == nil ? "person.2.fill" : "folder.fill",
                            showsChevron: false
                        )
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        RotaryGlassIconButton(systemName: "plus") {
                            RotaryHaptics.selection()
                            showingCreateAgent = true
                        }

                        RotaryGlassIconButton(systemName: "arrow.clockwise") {
                            RotaryHaptics.selection()
                            refresh()
                        }
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
        }
        .task(id: conversationPrefetchSignature) {
            await prefetchLikelyAgentConversations()
        }
    }

    private var agentsHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            RotaryInlineStatusHeader(subtitle: agentsHeaderSubtitle)

            RotarySearchField(text: $searchText, prompt: "Search agents")

            if let folders = bootstrap.folders, !folders.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        folderChip(title: "All", isActive: selectedFolderId == nil) {
                            selectedFolderId = nil
                        }

                        ForEach(folders) { folder in
                            folderChip(title: folder.name, isActive: selectedFolderId == folder.id) {
                                selectedFolderId = folder.id
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var agentsHeaderSubtitle: String? {
        if !searchText.isEmpty {
            return filteredAgents.isEmpty ? "No matches" : "\(filteredAgents.count) result\(filteredAgents.count == 1 ? "" : "s")"
        }
        if let currentFolder {
            return currentFolder.name
        }
        return nil
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

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Circle()
                .fill(RotaryTheme.softSurface)
                .frame(width: 68, height: 68)
                .overlay(
                    Image(systemName: "person.2")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.secondary)
                )
            Text(searchText.isEmpty ? "No agents yet" : "No matching agents")
                .font(.headline)
            Text(searchText.isEmpty ? "Create an agent to get started." : "Try a different search or folder.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if searchText.isEmpty {
                Button("Create Agent") {
                    showingCreateAgent = true
                }
                .buttonStyle(RotaryPrimaryButtonStyle())
                .padding(.top, 8)
                .frame(maxWidth: 220)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func latestPreview(for agent: MobileAgent) -> String {
        if let thread = relatedThreads(for: agent).first {
            return thread.preview
        }
        if let call = relatedCalls(for: agent).first {
            return call.summary ?? call.transcript ?? call.contactPhone ?? "Recent phone activity"
        }
        return ""
    }

    private func latestTimestampText(for agent: MobileAgent) -> String {
        let threadDate = relatedThreads(for: agent).compactMap { $0.lastMessageAt }.compactMap(parseDate).max()
        let callDate = relatedCalls(for: agent).compactMap { parseDate($0.createdAt) }.max()
        let agentDate = parseDate(agent.updatedAt)
        let date = [threadDate, callDate, agentDate].compactMap { $0 }.max()
        guard let date else { return "" }
        return RotaryDateFormatting.relativeTimestamp(for: date)
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

        for agent in candidates {
            do {
                _ = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                    try await api.agentConversation(
                        token: token,
                        agentId: agent.id,
                        forceRefresh: false
                    )
                }
            } catch {
                continue
            }
        }
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
            .navigationTitle("New Folder")
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
            .navigationTitle("Rename Folder")
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

    @State private var name = ""
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
        let sorted = voiceOptions.sorted { lhs, rhs in
            switch (lhs.previewUrl == nil, rhs.previewUrl == nil) {
            case (false, true): return true
            case (true, false): return false
            default: return lhs.name < rhs.name
            }
        }
        return Array(sorted.prefix(10))
    }

    private var displayVoiceOptions: [MobileVoicePreset] {
        if curatedVoiceOptions.isEmpty {
            return [
                MobileVoicePreset(
                    id: "fallback-rachel",
                    name: "Rachel",
                    provider: "elevenlabs",
                    category: "fallback",
                    description: "Warm and clear.",
                    previewUrl: nil,
                    labels: ["accent": "american", "gender": "female"]
                )
            ]
        }
        return curatedVoiceOptions
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Agent name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }

                Section("Popular Voices") {
                    if isLoadingVoices {
                        ProgressView()
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
            .navigationTitle("New Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isWorking ? "Creating" : "Create") {
                        Task { await submit() }
                    }
                    .disabled(isWorking || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedVoiceName.isEmpty)
                }
            }
        }
        .task {
            await loadVoices()
        }
        .onDisappear {
            previewPlayer.stop()
        }
    }

    private func loadVoices() async {
        isLoadingVoices = true
        defer { isLoadingVoices = false }

        do {
            voiceOptions = try await appModel.listVoicePresets()
            if let firstVoice = displayVoiceOptions.first {
                if selectedVoiceId == nil {
                    selectedVoiceId = firstVoice.id
                }
                if selectedVoiceName.isEmpty {
                    selectedVoiceName = firstVoice.name
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submit() async {
        isWorking = true
        defer { isWorking = false }

        do {
            try await appModel.createFirstAgent(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                purpose: "Everyday",
                voiceName: selectedVoiceName,
                voiceProfileId: selectedVoiceId,
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
            .navigationTitle("New Message")
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
            .navigationTitle("New Call")
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
