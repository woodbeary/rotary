import SwiftUI
import UIKit

private enum RotaryMessageInboxFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case known = "Known"
    case spam = "Spam"
    case deleted = "Deleted"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .known:
            return "Known"
        case .spam:
            return "Unknown & Spam"
        case .deleted:
            return "Recently Deleted"
        }
    }

    var icon: String {
        switch self {
        case .all:
            return "bubble.left.and.bubble.right.fill"
        case .known:
            return "person.crop.circle.badge.checkmark"
        case .spam:
            return "exclamationmark.bubble.fill"
        case .deleted:
            return "trash.fill"
        }
    }
}

private enum RotaryMessageSearchCategory: String, CaseIterable, Identifiable {
    case messages
    case files
    case photos
    case links
    case locations
    case documents

    var id: String { rawValue }

    var title: String {
        switch self {
        case .messages:
            return "Messages"
        case .files:
            return "Files"
        case .photos:
            return "Photos"
        case .links:
            return "Links"
        case .locations:
            return "Locations"
        case .documents:
            return "Documents"
        }
    }

    var systemImage: String {
        switch self {
        case .messages:
            return "bubble.left.and.bubble.right"
        case .files:
            return "folder"
        case .photos:
            return "photo.on.rectangle"
        case .links:
            return "link"
        case .locations:
            return "mappin.and.ellipse"
        case .documents:
            return "doc.text"
        }
    }
}

private struct RotaryMessageSearchEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
}

private enum RotaryMessageLineScopeStorage {
    static let key = "rotary.messages.inbox.lineScope"
    static let all = "__all_lines__"
}

#if DEBUG
private let rotaryDebugSeedThreadID = "debug-message-jacob-lopez"
private let rotaryDebugSeedContactID = "debug-contact-jacob-lopez"

private func rotaryDebugSeedThreadSummary(
    fromNumber: String,
    contactPhone: String?
) -> MobileThreadSummary {
    let resolvedContactPhone = contactPhone?.trimmingCharacters(in: .whitespacesAndNewlines)
        .nonEmptyTrimmed
        ?? fromNumber
    let now = ISO8601DateFormatter().string(from: Date())

    return MobileThreadSummary(
        threadId: rotaryDebugSeedThreadID,
        contactId: rotaryDebugSeedContactID,
        contactName: "Jacob Lopez",
        contactPhone: resolvedContactPhone,
        contactEmail: nil,
        preview: "Second live confirmation from crm message_local",
        lastDirection: "outbound",
        lastStatus: "sent",
        lastMessageAt: now,
        preferredFromNumber: fromNumber,
        unreadCount: 0,
        isDeleted: false,
        isSpam: false,
        contactLanguage: nil,
        userLanguage: nil,
        translationMode: nil,
        translationEnabled: nil
    )
}
#endif

struct RotaryMessagesScreen: View {
    let bootstrap: MobileBootstrapReadyState
    let store: MessagesStore
    let startCall: (_ phoneNumber: String, _ fromNumber: String?) -> Void
    let onUnreadCountChange: ((Int) -> Void)?
    @Binding var pendingThreadID: String?

    @State private var showingCompose = false
    @State private var selectedFilter: RotaryMessageInboxFilter = .all
    @State private var searchText = ""
    @State private var selectedThreadIDs = Set<String>()
    @State private var isEditing = false
    @State private var showingExportAgentPicker = false
    @State private var exportErrorMessage: String?
    @State private var isExportingToAgent = false
    @State private var activeSearchCategory: RotaryMessageSearchCategory?
    @FocusState private var isSearchFieldFocused: Bool
    @AppStorage(RotaryMessageLineScopeStorage.key) private var selectedLineScopeStorage = RotaryMessageLineScopeStorage.all
    @State private var navigationPath = NavigationPath()

    init(
        bootstrap: MobileBootstrapReadyState,
        store: MessagesStore,
        startCall: @escaping (_ phoneNumber: String, _ fromNumber: String?) -> Void,
        onUnreadCountChange: ((Int) -> Void)? = nil,
        pendingThreadID: Binding<String?>
    ) {
        self.bootstrap = bootstrap
        self.store = store
        self.startCall = startCall
        self.onUnreadCountChange = onUnreadCountChange
        _pendingThreadID = pendingThreadID
    }

    private var senderNumbers: [String] {
        var seen = Set<String>()
        var numbers: [String] = []

        if let ownerLine = normalizedNumber(bootstrap.ownerLine?.phoneNumber), seen.insert(ownerLine).inserted {
            numbers.append(ownerLine)
        }

        for line in bootstrap.lines where line.outboundSmsAllowed {
            guard let phoneNumber = normalizedNumber(line.phoneNumber), seen.insert(phoneNumber).inserted else {
                continue
            }
            numbers.append(phoneNumber)
        }

        return numbers
    }

    private var knownAgentPhoneNumbers: [String] {
        var known = Set<String>()

        for line in bootstrap.lines {
            let lineRole = line.role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let ownerType = line.ownerType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let ownershipScope = line.ownershipScope.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let lineID = line.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let friendlyName = line.friendlyName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let isAgentLine =
                lineRole.contains("agent")
                || ownerType == "agent"
                || ownershipScope.contains("agent")
                || lineID.contains("agent")
                || friendlyName?.contains("agent") == true
                || line.agentId != nil
            guard isAgentLine,
                  let normalized = rotaryCanonicalPhone(line.phoneNumber) else {
                continue
            }
            known.insert(normalized)
        }

        for agent in bootstrap.agents {
            guard let normalized = rotaryCanonicalPhone(agent.assignedPhoneNumber) else { continue }
            known.insert(normalized)
        }

        return Array(known)
    }

    private var allThreads: [MobileThreadSummary] {
        store.threads
    }

    private var selectedLineNumber: String? {
        guard selectedLineScopeStorage != RotaryMessageLineScopeStorage.all,
              let fromNumber = normalizedNumber(selectedLineScopeStorage),
              senderNumbers.contains(fromNumber) else {
            return nil
        }
        return fromNumber
    }

    private var composeFromNumber: String {
        selectedLineNumber
            ?? normalizedNumber(bootstrap.ownerLine?.phoneNumber)
            ?? normalizedNumber(bootstrap.capabilities.defaultMainLine)
            ?? senderNumbers.first
            ?? ""
    }

    private var lineScopedThreads: [MobileThreadSummary] {
        guard let selectedLineNumber else { return allThreads }
        let scoped = allThreads.filter { normalizedNumber($0.preferredFromNumber) == selectedLineNumber }
#if DEBUG
        if scoped.isEmpty, !allThreads.isEmpty {
            return allThreads
        }
#endif
        return scoped
    }

    private var filteredThreads: [MobileThreadSummary] {
        let base = lineScopedThreads.filter(matchesCurrentFilter)
        guard !searchText.isEmpty else { return base }
        let query = searchText.lowercased()
        return base.filter { thread in
            [
                thread.contactName.lowercased(),
                rotarySanitizedConversationPreview(thread.preview).lowercased(),
                thread.contactPhone?.lowercased(),
                thread.contactEmail?.lowercased(),
            ]
            .compactMap { $0 }
            .contains(where: { $0.contains(query) })
        }
    }

    private var displayThreads: [MobileThreadSummary] {
        if !filteredThreads.isEmpty {
            return filteredThreads
        }

#if DEBUG
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [debugSeedThread]
        }
#endif
        return []
    }

    private var unreadCountSignature: Int {
        store.filterCounts?.unread ?? store.unreadCount()
    }

    private var likelyThreadPrefetchSignature: String {
        filteredThreads
            .prefix(10)
            .map(\.id)
            .joined(separator: "|")
    }

    private var selectedContactIDs: [String] {
        Array(
            Set(
                threadsForSelection(selectedThreadIDs)
                    .map(\.contactId)
            )
        )
    }

    private var normalizedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var hasStructuredSearchResults: Bool {
        !normalizedSearchQuery.isEmpty
    }

    private var messageSearchEntries: [RotaryMessageSearchEntry] {
        guard hasStructuredSearchResults else { return [] }
        var entries: [RotaryMessageSearchEntry] = []
        let query = normalizedSearchQuery

        for thread in filteredThreads {
            if let detail = store.detail(threadID: thread.id) {
                for message in detail.messages {
                    let content = rotarySanitizedConversationText(message.content)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !content.isEmpty, content.lowercased().contains(query) else { continue }
                    entries.append(
                        RotaryMessageSearchEntry(
                            id: "message:\(thread.id):\(message.id)",
                            title: thread.contactName,
                            subtitle: messageSnippet(content, query: query)
                        )
                    )
                }
            } else {
                let preview = rotarySanitizedConversationPreview(thread.preview)
                guard preview.lowercased().contains(query) else { continue }
                entries.append(
                    RotaryMessageSearchEntry(
                        id: "preview:\(thread.id)",
                        title: thread.contactName,
                        subtitle: messageSnippet(preview, query: query)
                    )
                )
            }
        }

        return Array(entries.prefix(120))
    }

    private var fileSearchEntries: [RotaryMessageSearchEntry] {
        guard hasStructuredSearchResults else { return [] }
        let query = normalizedSearchQuery
        return filteredThreads.compactMap { thread in
            store.detail(threadID: thread.id).map { (thread, $0) }
        }
        .flatMap { thread, detail in
            rotaryThreadAssetItems(from: detail)
                .filter { $0.category == .file }
                .filter { item in
                    [
                        item.title.lowercased(),
                        item.subtitle.lowercased(),
                        item.urlString?.lowercased(),
                    ]
                    .compactMap { $0 }
                    .contains(where: { $0.contains(query) })
                }
                .map { item in
                    RotaryMessageSearchEntry(
                        id: "file:\(thread.id):\(item.id)",
                        title: item.title,
                        subtitle: thread.contactName
                    )
                }
        }
    }

    private var photoSearchEntries: [RotaryMessageSearchEntry] {
        guard hasStructuredSearchResults else { return [] }
        let query = normalizedSearchQuery
        return filteredThreads.compactMap { thread in
            store.detail(threadID: thread.id).map { (thread, $0) }
        }
        .flatMap { thread, detail in
            rotaryThreadAssetItems(from: detail)
                .filter { $0.category == .photo }
                .filter { item in
                    [
                        item.title.lowercased(),
                        item.subtitle.lowercased(),
                        item.urlString?.lowercased(),
                    ]
                    .compactMap { $0 }
                    .contains(where: { $0.contains(query) })
                }
                .map { item in
                    RotaryMessageSearchEntry(
                        id: "photo:\(thread.id):\(item.id)",
                        title: item.title,
                        subtitle: thread.contactName
                    )
                }
        }
    }

    private var linkSearchEntries: [RotaryMessageSearchEntry] {
        guard hasStructuredSearchResults else { return [] }
        let query = normalizedSearchQuery
        return filteredThreads.compactMap { thread in
            store.detail(threadID: thread.id).map { (thread, $0) }
        }
        .flatMap { thread, detail in
            rotaryThreadAssetItems(from: detail)
                .filter { $0.category == .link }
                .filter { item in
                    [
                        item.title.lowercased(),
                        item.subtitle.lowercased(),
                        item.urlString?.lowercased(),
                    ]
                    .compactMap { $0 }
                    .contains(where: { $0.contains(query) })
                }
                .map { item in
                    RotaryMessageSearchEntry(
                        id: "link:\(thread.id):\(item.id)",
                        title: item.title,
                        subtitle: thread.contactName
                    )
                }
        }
    }

    private var locationSearchEntries: [RotaryMessageSearchEntry] {
        guard hasStructuredSearchResults else { return [] }
        let query = normalizedSearchQuery
        return filteredThreads.compactMap { thread in
            store.detail(threadID: thread.id).map { (thread, $0) }
        }
        .flatMap { thread, detail in
            rotaryThreadLocationItems(from: detail, editedContact: nil)
                .filter { location in
                    [location.title.lowercased(), location.subtitle.lowercased()]
                        .contains(where: { $0.contains(query) })
                }
                .map { location in
                    RotaryMessageSearchEntry(
                        id: "location:\(thread.id):\(location.id)",
                        title: location.title,
                        subtitle: location.subtitle
                    )
                }
        }
    }

    private var documentSearchEntries: [RotaryMessageSearchEntry] {
        guard hasStructuredSearchResults else { return [] }
        let query = normalizedSearchQuery
        return fileSearchEntries.filter { entry in
            let haystack = "\(entry.title) \(entry.subtitle)".lowercased()
            guard haystack.contains(query) else { return false }
            return haystack.contains(".pdf")
                || haystack.contains(".doc")
                || haystack.contains(".docx")
                || haystack.contains("contract")
                || haystack.contains("invoice")
                || haystack.contains("permit")
        }
    }

    private func searchEntries(for category: RotaryMessageSearchCategory) -> [RotaryMessageSearchEntry] {
        switch category {
        case .messages:
            return messageSearchEntries
        case .files:
            return fileSearchEntries
        case .photos:
            return photoSearchEntries
        case .links:
            return linkSearchEntries
        case .locations:
            return locationSearchEntries
        case .documents:
            return documentSearchEntries
        }
    }

    private var searchCategoryCounts: [(category: RotaryMessageSearchCategory, count: Int)] {
        RotaryMessageSearchCategory.allCases.map { category in
            (category, searchEntries(for: category).count)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                RotaryBackdrop(onTap: { RotaryKeyboard.dismiss() })

                VStack(spacing: 0) {
                    if hasStructuredSearchResults {
                        searchCategoryCards
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                    }

                    if displayThreads.isEmpty {
                        emptyState
                    } else {
                        List(displayThreads) { thread in
                            if isEditing {
                                editableRow(thread)
                            } else {
                                NavigationLink(value: thread.id) {
                                    RotaryConversationSummaryRow(
                                        title: thread.contactName,
                                        preview: threadPreviewText(for: thread),
                                        timestamp: thread.lastMessageAt.map(RotaryDateFormatting.listTimestamp) ?? "",
                                        avatarURL: nil,
                                        avatarSize: 50,
                                        isUnread: (thread.unreadCount ?? 0) > 0,
                                        previewSystemImage: threadPreviewTranslationIcon(for: thread)
                                    )
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        Task {
                                            await store.performThreadAction(
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
                                    if thread.isSpam == true {
                                        Button {
                                            Task {
                                                await store.performThreadAction(contactIds: [thread.contactId], action: "unmark_spam")
                                            }
                                        } label: {
                                            Label("Inbox", systemImage: "tray.and.arrow.down")
                                        }
                                        .tint(RotaryTheme.accent)
                                    } else if thread.isDeleted == true {
                                        Button {
                                            Task {
                                                await store.performThreadAction(contactIds: [thread.contactId], action: "restore")
                                            }
                                        } label: {
                                            Label("Recover", systemImage: "arrow.uturn.backward")
                                        }
                                        .tint(RotaryTheme.accent)
                                    } else {
                                        Button(role: .destructive) {
                                            Task {
                                                await store.performThreadAction(contactIds: [thread.contactId], action: "move_to_deleted")
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }

                                        Button {
                                            Task {
                                                await store.performThreadAction(contactIds: [thread.contactId], action: "mark_spam")
                                            }
                                        } label: {
                                            Label("Spam", systemImage: "exclamationmark.bubble")
                                        }
                                        .tint(RotaryTheme.warning)
                                    }
                                }
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                        .scrollDismissesKeyboard(.interactively)
                        .scrollContentBackground(.hidden)
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isEditing {
                    bulkActionBar
                } else {
                    messagesBottomBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbar(.visible, for: .tabBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: toggleEditing) {
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
                    HStack(spacing: 8) {
                        Menu {
                            Section("View by Line") {
                                Button {
                                    setSelectedLineScope(nil)
                                } label: {
                                    Label(
                                        "All Lines",
                                        systemImage: selectedLineNumber == nil ? "checkmark.circle.fill" : "circle"
                                    )
                                }

                                ForEach(senderNumbers, id: \.self) { fromNumber in
                                    Button {
                                        setSelectedLineScope(fromNumber)
                                    } label: {
                                        Label(
                                            fromNumber,
                                            systemImage: selectedLineNumber == fromNumber ? "checkmark.circle.fill" : "circle"
                                        )
                                    }
                                }
                            }

                            Section("Filters") {
                                ForEach(RotaryMessageInboxFilter.allCases) { filter in
                                    Button {
                                        RotaryHaptics.selection()
                                        selectedFilter = filter
                                    } label: {
                                        Label(filter.title, systemImage: filter.icon)
                                    }
                                }
                            }

                            Section("Inbox") {
                                if filteredThreads.contains(where: { ($0.unreadCount ?? 0) > 0 }) {
                                    Button("Mark Visible Read", systemImage: "envelope.open") {
                                        let visibleUnread = filteredThreads
                                            .filter { ($0.unreadCount ?? 0) > 0 }
                                            .map(\.contactId)
                                        Task {
                                            await store.performThreadAction(contactIds: visibleUnread, action: "mark_read")
                                        }
                                    }
                                }
                            }

                            if isEditing {
                                Section("Selected") {
                                    Button("Select All", systemImage: "checkmark.circle") {
                                        selectedThreadIDs = Set(filteredThreads.map(\.id))
                                    }
                                    Button("Deselect All", systemImage: "circle") {
                                        selectedThreadIDs.removeAll()
                                    }
                                    Divider()
                                    Button("Mark Read", systemImage: "envelope.open") {
                                        Task { await store.performThreadAction(contactIds: selectedContactIDs, action: "mark_read") }
                                    }
                                    Button("Mark Unread", systemImage: "envelope.badge") {
                                        Task { await store.performThreadAction(contactIds: selectedContactIDs, action: "mark_unread") }
                                    }
                                    Button(selectedFilter == .deleted ? "Recover" : "Delete", systemImage: selectedFilter == .deleted ? "arrow.uturn.backward" : "trash") {
                                        Task {
                                            await store.performThreadAction(
                                                contactIds: selectedContactIDs,
                                                action: selectedFilter == .deleted ? "restore" : "move_to_deleted"
                                            )
                                        }
                                    }
                                    if selectedFilter == .spam {
                                        Button("Move to Inbox", systemImage: "tray.and.arrow.down") {
                                            Task { await store.performThreadAction(contactIds: selectedContactIDs, action: "unmark_spam") }
                                        }
                                    } else if selectedFilter != .deleted {
                                        Button("Move to Spam", systemImage: "exclamationmark.bubble") {
                                            Task { await store.performThreadAction(contactIds: selectedContactIDs, action: "mark_spam") }
                                        }
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
                                .accessibilityLabel("Inbox options")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCompose) {
                RotaryComposeMessageSheet(
                    senderNumbers: senderNumbers,
                    initialFromNumber: composeFromNumber,
                    store: store,
                    knownAgentPhoneNumbers: knownAgentPhoneNumbers
                )
            }
            .sheet(item: $activeSearchCategory) { category in
                NavigationStack {
                    RotaryMessageSearchCategorySheet(
                        category: category,
                        query: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
                        entries: searchEntries(for: category)
                    )
                }
            }
            .confirmationDialog(
                "Load Selected Into Agent",
                isPresented: $showingExportAgentPicker,
                titleVisibility: .visible
            ) {
                ForEach(bootstrap.agents) { agent in
                    Button(agent.name) {
                        Task { await exportSelection(to: agent) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose an agent to receive the selected conversations.")
            }
            .alert("Export Failed", isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportErrorMessage ?? "")
            }
            .navigationDestination(for: String.self) { threadID in
                RotaryThreadResolverScreen(
                    threadID: threadID,
                    senderNumbers: senderNumbers,
                    ownerLine: bootstrap.ownerLine?.phoneNumber ?? bootstrap.capabilities.defaultMainLine,
                    fallbackContactPhone: bootstrap.ownerCellNumber ?? bootstrap.ownerLine?.phoneNumber,
                    store: store,
                    startCall: startCall
                )
            }
        }
        .task {
            if selectedLineScopeStorage != RotaryMessageLineScopeStorage.all,
               selectedLineNumber == nil {
                selectedLineScopeStorage = RotaryMessageLineScopeStorage.all
            }
            publishUnreadCount()
            await store.refreshInbox()
        }
        .task(id: likelyThreadPrefetchSignature) {
            await prefetchLikelyThreads()
        }
        .onChange(of: unreadCountSignature) { _, _ in
            publishUnreadCount()
        }
        .onChange(of: searchText) { _, value in
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                activeSearchCategory = nil
            }
        }
        .onChange(of: selectedLineScopeStorage) { _, _ in
            let visibleIDs = Set(filteredThreads.map(\.id))
            selectedThreadIDs = selectedThreadIDs.intersection(visibleIDs)
            activeSearchCategory = nil
        }
        .task(id: pendingThreadID) {
            await openPendingThreadIfNeeded()
        }
    }

    private var inboxHeader: some View { EmptyView() }

    private func toggleEditing() {
        RotaryHaptics.selection()
        withAnimation(.easeInOut(duration: 0.18)) {
            isEditing.toggle()
            if !isEditing {
                selectedThreadIDs.removeAll()
            }
        }
    }

    private var bulkActionBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                bulkActionButton("Read", systemImage: "envelope.open") {
                    Task { await store.performThreadAction(contactIds: selectedContactIDs, action: "mark_read") }
                }
                bulkActionButton("Unread", systemImage: "envelope.badge") {
                    Task { await store.performThreadAction(contactIds: selectedContactIDs, action: "mark_unread") }
                }
                bulkActionButton(selectedFilter == .deleted ? "Recover" : "Delete", systemImage: selectedFilter == .deleted ? "arrow.uturn.backward" : "trash") {
                    Task {
                        await store.performThreadAction(
                            contactIds: selectedContactIDs,
                            action: selectedFilter == .deleted ? "restore" : "move_to_deleted"
                        )
                    }
                }
                if selectedFilter == .spam {
                    bulkActionButton("Inbox", systemImage: "tray.and.arrow.down") {
                        Task { await store.performThreadAction(contactIds: selectedContactIDs, action: "unmark_spam") }
                    }
                } else if selectedFilter != .deleted {
                    bulkActionButton("Spam", systemImage: "exclamationmark.bubble") {
                        Task { await store.performThreadAction(contactIds: selectedContactIDs, action: "mark_spam") }
                    }
                }

                if !bootstrap.agents.isEmpty {
                    bulkActionButton(isExportingToAgent ? "Exporting" : "To Agent", systemImage: "person.2.badge.gearshape") {
                        guard !isExportingToAgent else { return }
                        showingExportAgentPicker = true
                    }
                    .disabled(selectedThreadIDs.isEmpty || isExportingToAgent)
                    .opacity(selectedThreadIDs.isEmpty || isExportingToAgent ? 0.45 : 1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
    }

    private var messagesBottomBar: some View {
        HStack(alignment: .center, spacing: 10) {
            RotarySearchField(
                text: $searchText,
                prompt: "Search",
                onMic: {
                    RotaryHaptics.selection()
                    isSearchFieldFocused = true
                },
                isFocused: $isSearchFieldFocused
            )

            Button {
                RotaryHaptics.selection()
                showingCompose = true
            } label: {
                Image(systemName: "square.and.pencil")
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
            .accessibilityLabel("New message")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var searchCategoryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(searchCategoryCounts, id: \.category.id) { summary in
                searchCategoryCard(category: summary.category, count: summary.count)
            }
        }
    }

    private func searchCategoryCard(category: RotaryMessageSearchCategory, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RotaryTheme.accent)
                Text(category.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Button {
                activeSearchCategory = category
            } label: {
                HStack(spacing: 4) {
                    Text("See all")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(count > 0 ? RotaryTheme.accent : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(count == 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RotaryTheme.incomingBubble, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
        )
    }

    private func editableRow(_ thread: MobileThreadSummary) -> some View {
        Button {
            RotaryHaptics.selection()
            if selectedThreadIDs.contains(thread.id) {
                selectedThreadIDs.remove(thread.id)
            } else {
                selectedThreadIDs.insert(thread.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedThreadIDs.contains(thread.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(selectedThreadIDs.contains(thread.id) ? RotaryTheme.accent : .secondary)
                RotaryConversationSummaryRow(
                    title: thread.contactName,
                    preview: threadPreviewText(for: thread),
                    timestamp: thread.lastMessageAt.map(RotaryDateFormatting.listTimestamp) ?? "",
                    avatarURL: nil,
                    avatarSize: 50,
                    isUnread: (thread.unreadCount ?? 0) > 0,
                    previewSystemImage: threadPreviewTranslationIcon(for: thread)
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowSeparator(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
#if DEBUG
            Spacer(minLength: 120)

            NavigationLink(value: debugSeedThread.id) {
                RotaryConversationSummaryRow(
                    title: debugSeedThread.contactName,
                    preview: debugSeedThread.preview,
                    timestamp: RotaryDateFormatting.listTimestamp(debugSeedThread.lastMessageAt ?? ""),
                    avatarURL: nil,
                    avatarSize: 50,
                    isUnread: false
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
#else
            Spacer()
#endif
            if let inboxError = store.inboxError, !inboxError.isEmpty {
                Text(inboxError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
#if DEBUG
            Spacer(minLength: 120)
#else
            Spacer()
#endif
        }
        .padding(.horizontal, 24)
    }

#if DEBUG
    private var debugSeedThread: MobileThreadSummary {
        rotaryDebugSeedThreadSummary(
            fromNumber: composeFromNumber,
            contactPhone: bootstrap.ownerCellNumber ?? bootstrap.ownerLine?.phoneNumber
        )
    }
#endif

    private func matchesCurrentFilter(_ thread: MobileThreadSummary) -> Bool {
        switch selectedFilter {
        case .all:
            return thread.isDeleted != true && thread.isSpam != true
        case .known:
            return thread.isDeleted != true && thread.isSpam != true && rotaryLooksLikeNamedSender(thread.contactName)
        case .spam:
            return thread.isSpam == true
        case .deleted:
            return thread.isDeleted == true
        }
    }

    private func publishUnreadCount() {
        onUnreadCountChange?(store.unreadCount())
    }

    private func setSelectedLineScope(_ fromNumber: String?) {
        RotaryHaptics.selection()
        selectedLineScopeStorage = normalizedNumber(fromNumber) ?? RotaryMessageLineScopeStorage.all
    }

    private func threadRecord(for threadID: String) -> MobileThreadSummary? {
        allThreads.first { thread in
            thread.id == threadID || thread.threadId == threadID || thread.contactId == threadID
        }
    }

    private func openPendingThreadIfNeeded() async {
        guard let pendingThreadID = pendingThreadID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !pendingThreadID.isEmpty else {
            return
        }

        if threadRecord(for: pendingThreadID) == nil {
            await store.refreshInbox()
        }

        guard let resolvedThread = threadRecord(for: pendingThreadID) else {
            self.pendingThreadID = nil
            return
        }

        navigationPath = NavigationPath()
        navigationPath.append(resolvedThread.id)
        self.pendingThreadID = nil
    }

    private func prefetchLikelyThreads() async {
        let candidates = Array(filteredThreads.prefix(searchText.isEmpty ? 10 : 12))
        guard !candidates.isEmpty else { return }
        await store.prefetchThreadsIfNeeded(candidates, limit: candidates.count)
    }

    private func messageSnippet(_ text: String, query: String) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }

        let lowered = normalized.lowercased()
        guard let range = lowered.range(of: query) else {
            return normalized
        }

        let distance = lowered.distance(from: lowered.startIndex, to: range.lowerBound)
        let startOffset = max(0, distance - 32)
        let endOffset = min(normalized.count, distance + query.count + 48)

        let startIndex = normalized.index(normalized.startIndex, offsetBy: startOffset)
        let endIndex = normalized.index(normalized.startIndex, offsetBy: endOffset)
        var snippet = String(normalized[startIndex..<endIndex])

        if startOffset > 0 {
            snippet = "…\(snippet)"
        }
        if endOffset < normalized.count {
            snippet += "…"
        }
        return snippet
    }

    private func threadPreviewText(for thread: MobileThreadSummary) -> String {
        guard let lastMessage = store.detail(threadID: thread.id)?.messages.last else {
            return thread.preview
        }

        if let rendered = lastMessage.renderedContent?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rendered.isEmpty {
            return rendered
        }
        if let display = lastMessage.displayContent?.trimmingCharacters(in: .whitespacesAndNewlines),
           !display.isEmpty {
            return display
        }
        return lastMessage.content
    }

    private func threadPreviewTranslationIcon(for thread: MobileThreadSummary) -> String? {
        guard let lastMessage = store.detail(threadID: thread.id)?.messages.last else {
            return nil
        }

        let rendered = (
            lastMessage.renderedContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        ) ? (lastMessage.renderedContent ?? lastMessage.content) : (
            lastMessage.displayContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        ) ? (lastMessage.displayContent ?? lastMessage.content) : lastMessage.content

        if let original = lastMessage.originalContent?.trimmingCharacters(in: .whitespacesAndNewlines),
           !original.isEmpty,
           original != rendered.trimmingCharacters(in: .whitespacesAndNewlines) {
            return "globe"
        }

        guard let status = lastMessage.translationStatus?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !status.isEmpty else {
            return nil
        }
        if status.contains("translated")
            || status.contains("success")
            || status.contains("complete") {
            return "globe"
        }
        return nil
    }

    private func normalizedNumber(_ value: String?) -> String? {
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

    private func bulkActionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .disabled(selectedThreadIDs.isEmpty)
        .opacity(selectedThreadIDs.isEmpty ? 0.45 : 1)
    }

    private func threadsForSelection(_ ids: Set<String>) -> [MobileThreadSummary] {
        let idSet = Set(ids)
        return filteredThreads.filter { idSet.contains($0.id) }
    }

    private func exportSelection(to agent: MobileAgent) async {
        let selection = Array(selectedThreadIDs)
        guard !selection.isEmpty else { return }
        isExportingToAgent = true
        defer { isExportingToAgent = false }

        do {
            try await store.exportThreadsToAgent(agentId: agent.id, threadIDs: selection)
            RotaryHaptics.success()
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedThreadIDs.removeAll()
                isEditing = false
            }
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }
}

private struct RotaryThreadResolverScreen: View {
    let threadID: String
    let senderNumbers: [String]
    let ownerLine: String
    let fallbackContactPhone: String?
    let store: MessagesStore
    let startCall: (_ phoneNumber: String, _ fromNumber: String?) -> Void

    @State private var isResolving = false
    @State private var resolveAttempt = 0

    private var resolvedThread: MobileThreadSummary? {
        if let resolved = store.thread(threadID: threadID)
            ?? store.threads.first(where: { $0.contactId == threadID || $0.threadId == threadID }) {
            return resolved
        }
#if DEBUG
        if threadID == rotaryDebugSeedThreadID {
            return rotaryDebugSeedThreadSummary(
                fromNumber: ownerLine,
                contactPhone: fallbackContactPhone
            )
        }
#endif
        return nil
    }

    var body: some View {
        Group {
            if let resolvedThread {
                RotaryMessageThreadScreen(
                    thread: resolvedThread,
                    senderNumbers: senderNumbers,
                    ownerLine: ownerLine,
                    store: store,
                    startCall: startCall
                )
            } else if isResolving {
                VStack(spacing: 12) {
                    ProgressView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RotaryBackdrop())
            } else {
                RotaryThreadUnavailableScreen {
                    resolveAttempt += 1
                }
            }
        }
        .task(id: resolveAttempt) {
            await resolveThread()
        }
    }

    @MainActor
    private func resolveThread() async {
        guard resolvedThread == nil else { return }
        isResolving = true
        defer { isResolving = false }

        await store.refreshInbox(forceRefresh: resolveAttempt > 0)
        if let resolvedThread {
            await store.prefetchThreadIfNeeded(resolvedThread)
        }
    }
}

private struct RotaryThreadUnavailableScreen: View {
    let onRetry: (() -> Void)?

    init(onRetry: (() -> Void)? = nil) {
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            if let onRetry {
                Button {
                    RotaryHaptics.selection()
                    onRetry()
                } label: {
                    RotaryGlassIcon(systemName: "arrow.clockwise", size: 12, frameSize: 36)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 16)
        .background(RotaryBackdrop())
    }
}

private struct RotaryMessageSearchCategorySheet: View {
    @Environment(\.dismiss) private var dismiss

    let category: RotaryMessageSearchCategory
    let query: String
    let entries: [RotaryMessageSearchEntry]

    var body: some View {
        List {
            if entries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: category.systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("No \(category.title.lowercased()) found")
                        .font(.subheadline.weight(.semibold))
                    Text("Try another search term.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                                .font(.subheadline.weight(.semibold))
                            Text(entry.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(RotaryBackdrop())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("\"\(query)\"")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

struct RotaryMessageThreadScreen: View {
    @Environment(\.dismiss) private var dismiss

    let thread: MobileThreadSummary
    let senderNumbers: [String]
    let ownerLine: String
    let store: MessagesStore
    let startCall: (_ phoneNumber: String, _ fromNumber: String?) -> Void

    @State private var message = ""
    @State private var showingInfo = false
    @FocusState private var composerFocused: Bool
    @State private var messageSelectionMode = false
    @State private var selectedMessageIDs = Set<String>()
    @State private var tapbacksByMessageID: [String: String] = [:]
    @State private var showingShareComposer = false
    @State private var shareDraftMessage = ""
    @State private var inlineMenuNotice: String?
    @State private var pendingCallNumber: String?
    @State private var showingCallConfirmation = false
    @State private var translationDetailBubble: RotaryConversationBubbleModel?
    @State private var hasAppliedInitialBottomScroll = false

    private var currentThread: MobileThreadSummary {
        store.thread(threadID: thread.id) ?? thread
    }

    private var currentThreadDetail: MobileThreadDetail? {
        store.detail(threadID: currentThread.id)
    }

    private var headerTitle: String {
        if headerParticipants.count > 1 {
            return "\(headerParticipants.count) People"
        }
        let normalized = currentThread.contactName.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "Unknown" : normalized
    }

    private var headerParticipants: [String] {
        rotaryThreadParticipantTitles(
            for: currentThread,
            detail: currentThreadDetail,
            ownerLineNumber: ownerLine
        )
    }

    private var headerDisplayName: String {
        if headerTitle.hasSuffix(" People") {
            return headerTitle
        }
        let firstWord = headerTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .first
        return firstWord.map(String.init) ?? headerTitle
    }

    private var effectiveFromNumber: String {
        let preferred = store.threadViewState(for: currentThread).preferredFromNumber?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let preferred, senderNumbers.contains(preferred) {
            return preferred
        }

        let fallback = currentThread.preferredFromNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if senderNumbers.contains(fallback) {
            return fallback
        }

        return senderNumbers.first ?? ownerLine
    }

    private var state: MessagesStore.ThreadViewState {
        store.threadViewState(for: currentThread)
    }

    private var displayedMessages: [DisplayedThreadMessage] {
        state.messages
    }

    private var translationDecisionPrompt: MessagesStore.TranslationDecisionPrompt? {
        guard let prompt = store.translationDecisionPrompt,
              prompt.threadID == currentThread.id else {
            return nil
        }
        return prompt
    }

    private var isTranslationDecisionPresented: Binding<Bool> {
        Binding(
            get: { translationDecisionPrompt != nil },
            set: { presented in
                if !presented {
                    store.clearTranslationDecisionPrompt()
                }
            }
        )
    }

    private var transcriptMessages: [RotaryConversationBubbleModel] {
        displayedMessages.map { item in
            RotaryConversationBubbleModel(
                id: item.id,
                direction: item.direction == "outbound" ? .outbound : .inbound,
                text: rotarySanitizedConversationText(item.content),
                originalText: item.originalContent.map(rotarySanitizedConversationText),
                sourceLanguage: item.sourceLanguage,
                targetLanguage: item.targetLanguage,
                timestamp: RotaryDateFormatting.messageTimeOnly(item.sentAt),
                date: RotaryDateFormatting.parse(item.sentAt),
                statusText: nil,
                deliveryReceipt: conversationReceipt(for: item),
                statusSystemImage: providerStatusSymbol(for: item),
                wasTranslated: item.wasTranslated,
                attachments: [],
                isPreviewPlaceholder: item.isPreviewPlaceholder
            )
        }
    }

    var body: some View {
        ZStack {
            RotaryBackdrop(onTap: { composerFocused = false })
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if displayedMessages.isEmpty {
                    emptyConversationState
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                RotaryConversationTranscriptView(
                                    messages: transcriptMessages,
                                    selectionMode: messageSelectionMode,
                                    selectedMessageIDs: selectedMessageIDs,
                                    onToggleMessageSelection: { bubble in
                                        toggleMessageSelection(bubble.id)
                                    },
                                    onCopyMessage: { bubble in
                                        copyToPasteboard(bubble.text)
                                    },
                                    onTranslateMessage: { bubble in
                                        handleTranslateAction(for: bubble)
                                    },
                                    onSelectComposer: {
                                        composerFocused = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                            RotaryKeyboard.selectAll()
                                        }
                                    },
                                    onMoreMessage: { bubble in
                                        enterMessageSelectionMode(startingWith: bubble.id)
                                    },
                                    tapbackByMessageID: tapbacksByMessageID,
                                    onSetTapback: { bubble, emoji in
                                        tapbacksByMessageID[bubble.id] = emoji
                                    }
                                )
                                .id(displayedMessages.count)

                                Color.clear
                                    .frame(height: 1)
                                    .id("thread-bottom-anchor")
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
                        .onChange(of: displayedMessages.count) { _, _ in
                            scrollToBottom(proxy: proxy, animated: false)
                        }
                    }
                }

                if messageSelectionMode {
                    messageSelectionBar
                } else {
                    composer
                }
            }
        }
        .onDisappear {
            composerFocused = false
            hasAppliedInitialBottomScroll = false
        }
        .navigationTitle("")
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
                messageConversationHeader
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                if let phoneNumber = currentThread.contactPhone {
                    RotaryGlassIconButton(systemName: "phone.fill") {
                        composerFocused = false
                        pendingCallNumber = phoneNumber
                        showingCallConfirmation = true
                    }
                } else {
                    RotaryGlassIconButton(systemName: "info.circle.fill") {
                        composerFocused = false
                        showingInfo = true
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingInfo) {
            RotaryThreadInfoOverlay(
                thread: currentThread,
                detail: store.detail(threadID: currentThread.id),
                store: store,
                fromNumber: effectiveFromNumber,
                startCall: startCall,
                onClose: { showingInfo = false }
            )
            .presentationBackground(.clear)
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingShareComposer) {
            RotaryComposeMessageSheet(
                senderNumbers: senderNumbers,
                initialFromNumber: effectiveFromNumber,
                store: store,
                knownAgentPhoneNumbers: [],
                initialMessage: shareDraftMessage
            )
        }
        .sheet(item: $translationDetailBubble) { bubble in
            RotaryTranslationDetailSheet(bubble: bubble)
        }
        .confirmationDialog(
            "Call \(currentThread.contactName)?",
            isPresented: $showingCallConfirmation,
            titleVisibility: .visible
        ) {
            Button("Call") {
                guard let phoneNumber = pendingCallNumber ?? currentThread.contactPhone else { return }
                startCall(phoneNumber, effectiveFromNumber)
            }
            Button("Cancel", role: .cancel) {
                pendingCallNumber = nil
            }
        } message: {
            Text((pendingCallNumber ?? currentThread.contactPhone) ?? "Start a phone call from this conversation.")
        }
        .confirmationDialog(
            "Translation unavailable",
            isPresented: isTranslationDecisionPresented,
            titleVisibility: .visible
        ) {
            if let prompt = translationDecisionPrompt {
                Button("Retry Translation") {
                    Task {
                        await store.resolveTranslationDecision(
                            promptID: prompt.id,
                            action: "retry_translation"
                        )
                    }
                }

                Button("Send Original") {
                    Task {
                        await store.resolveTranslationDecision(
                            promptID: prompt.id,
                            action: "send_original"
                        )
                    }
                }
            }

            Button("Cancel", role: .cancel) {
                store.clearTranslationDecisionPrompt()
            }
        } message: {
            Text(translationDecisionPrompt?.message ?? "Choose how to send this message.")
        }
        .overlay(alignment: .topTrailing) {
            if messageSelectionMode {
                Button {
                    clearMessageSelection()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(RotaryTheme.secondarySurface, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .padding(.top, 56)
            }
        }
        .task(id: currentThread.id) {
            await store.ensureThreadLoaded(currentThread, markRead: true)
        }
    }

    private var composer: some View {
        VStack(spacing: 6) {
            if let inlineMenuNotice, !inlineMenuNotice.isEmpty {
                Text(inlineMenuNotice)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            }

            if let errorMessage = state.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
            }

            RotaryComposerBar(
                text: $message,
                placeholder: "",
                maxLines: 1 ... 4,
                isWorking: false,
                isFocused: $composerFocused,
                showsMenu: true,
                onMic: nil,
                onSend: {
                    Task { await sendMessage() }
                }
            ) {
                Section("Actions") {
                    Button("Camera", systemImage: "camera.fill") {}
                    Button("Photos", systemImage: "photo.on.rectangle") {}
                    Button("Audio", systemImage: "waveform") {}
                    Button("Send Later", systemImage: "clock.badge") {}
                    Button("Create Image", systemImage: "sparkles.rectangle.stack") {}
                    Button("Add Files", systemImage: "paperclip") {}
                }
            }
        }
        .padding(.bottom, 10)
    }

    private var messageSelectionBar: some View {
        VStack(spacing: 8) {
            Text(selectedMessageIDs.isEmpty ? "Select messages" : "\(selectedMessageIDs.count) selected")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    if selectedMessageIDs.isEmpty {
                        inlineMenuNotice = "Select at least one message."
                        return
                    }
                    selectedMessageIDs.removeAll()
                    inlineMenuNotice = "Selection cleared."
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 42, height: 42)
                        .background(RotaryTheme.secondarySurface, in: Circle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button {
                    startShareFlowFromSelection()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 42, height: 42)
                        .background(RotaryTheme.secondarySurface, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(selectedMessageIDs.isEmpty)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 6)
        }
        .padding(.top, 8)
    }

    private func sendMessage() async {
        let outgoing = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !outgoing.isEmpty else { return }

        message = ""
        RotaryHaptics.softTap()
        await store.sendMessage(in: currentThread, fromNumber: effectiveFromNumber, message: outgoing)
    }

    private func toggleMessageSelection(_ messageID: String) {
        if selectedMessageIDs.contains(messageID) {
            selectedMessageIDs.remove(messageID)
        } else {
            selectedMessageIDs.insert(messageID)
        }
    }

    private func enterMessageSelectionMode(startingWith messageID: String) {
        messageSelectionMode = true
        selectedMessageIDs = [messageID]
        composerFocused = false
    }

    private func clearMessageSelection() {
        messageSelectionMode = false
        selectedMessageIDs.removeAll()
    }

    private func startShareFlowFromSelection() {
        guard !selectedMessageIDs.isEmpty else { return }
        let selectedContent = displayedMessages
            .filter { selectedMessageIDs.contains($0.id) }
            .map(\.content)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        shareDraftMessage = selectedContent.joined(separator: "\n\n")
        showingShareComposer = true
        clearMessageSelection()
    }

    private func copyToPasteboard(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UIPasteboard.general.string = trimmed
        inlineMenuNotice = "Copied"
    }

    private func handleTranslateAction(for bubble: RotaryConversationBubbleModel) {
        RotaryHaptics.selection()
        translationDetailBubble = bubble
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard !displayedMessages.isEmpty else { return }

        let performScroll = {
            proxy.scrollTo("thread-bottom-anchor", anchor: .bottom)
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

    private func conversationReceipt(for item: DisplayedThreadMessage) -> RotaryMessageDeliveryReceipt? {
        guard item.direction == "outbound",
              let receipt = item.deliveryReceipt else {
            return nil
        }

        switch receipt {
        case .sent:
            return .sent
        case .delivered:
            return .delivered
        case .read:
            return .read
        case .undelivered:
            return .undelivered
        }
    }

    private func providerStatusSymbol(for item: DisplayedThreadMessage) -> String? {
        let normalizedStatus = item.status
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedTranslation = item.translationStatus?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let normalizedContent = item.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedOriginal = item.originalContent?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let marker = "\(normalizedStatus) \(normalizedTranslation) \(normalizedContent) \(normalizedOriginal)"

        if marker.contains("message_local")
            || marker.contains("local_model")
            || marker.contains("local")
            || marker.contains("offline")
            || marker.contains("ondevice")
            || marker.contains("on-device") {
            return "iphone.gen3"
        }

        if marker.contains("message_cloud")
            || marker.contains("cloud")
            || marker.contains("remote") {
            return "cloud.fill"
        }

        return nil
    }

    private func openContactInfo() {
        composerFocused = false
        showingInfo = true
    }

    private var emptyThreadTitle: some View {
        RotaryConversationThreadHeader(
            title: headerDisplayName,
            avatarSize: 42,
            participantTitles: headerParticipants,
            action: openContactInfo
        )
        .accessibilityLabel("Open \(headerTitle) info")
    }

    private var messageConversationHeader: some View {
        RotaryConversationThreadHeader(
            title: headerDisplayName,
            avatarSize: 44,
            participantTitles: headerParticipants,
            action: openContactInfo
        )
        .accessibilityLabel("Open \(headerTitle) info")
    }

    private var emptyConversationState: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 24)

            VStack(spacing: 10) {
                RotaryAvatarView(title: headerTitle, size: 56)

                Text("No conversation history yet")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Send the first message to start the thread. Replies will appear here.")
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
        .padding(.horizontal, 20)
    }
}

private struct RotaryTranslationDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let bubble: RotaryConversationBubbleModel

    private var originalText: String? {
        let trimmed = bubble.originalText?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let originalText {
                        RotaryGlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Original")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(originalText)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                        }
                    }

                    RotaryGlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(originalText == nil ? "Message" : "Translated")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(bubble.text)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }
            .background(RotaryBackdrop())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = originalText ?? bubble.text
                        RotaryHaptics.selection()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }
}

private struct RotaryComposeMessageSheet: View {
    @Environment(\.dismiss) private var dismiss

    let senderNumbers: [String]
    let initialFromNumber: String
    let store: MessagesStore
    let knownAgentPhoneNumbers: Set<String>
    let initialMessage: String

    @State private var recipientQuery = ""
    @State private var selectedRecipients: [MobileContactSearchResult] = []
    @State private var suggestions: [MobileContactSearchResult] = []
    @State private var message = ""
    @State private var selectedFromNumber = ""
    @State private var errorMessage: String?
    @State private var isSearching = false
    @State private var showingCreateContact = false

    init(
        senderNumbers: [String],
        initialFromNumber: String,
        store: MessagesStore,
        knownAgentPhoneNumbers: [String],
        initialMessage: String = ""
    ) {
        self.senderNumbers = senderNumbers
        self.initialFromNumber = initialFromNumber
        self.store = store
        self.knownAgentPhoneNumbers = Set(knownAgentPhoneNumbers.compactMap(rotaryCanonicalPhone))
        self.initialMessage = initialMessage
    }

    private var trimmedRecipientQuery: String {
        recipientQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canShowRawRecipientSuggestion: Bool {
        !trimmedRecipientQuery.isEmpty
            && !selectedRecipients.contains(where: { $0.phoneNumber == trimmedRecipientQuery || $0.name == trimmedRecipientQuery })
            && !suggestions.contains(where: { $0.phoneNumber == trimmedRecipientQuery || $0.name.caseInsensitiveCompare(trimmedRecipientQuery) == .orderedSame })
    }

    private var rawRecipientSuggestion: MobileContactSearchResult {
        MobileContactSearchResult(
            id: "manual:\(trimmedRecipientQuery)",
            kind: "manual",
            name: trimmedRecipientQuery,
            phoneNumber: trimmedRecipientQuery,
            subtitle: nil
        )
    }

    private var existingThreadPreview: MobileThreadSummary? {
        guard selectedRecipients.count == 1,
              let phoneNumber = selectedRecipients.first?.phoneNumber else {
            return nil
        }
        let normalizedPhone = normalizedNumber(phoneNumber)
        let normalizedFromNumber = normalizedNumber(selectedFromNumber.isEmpty ? initialFromNumber : selectedFromNumber)

        let matches = store.threads.filter { thread in
            normalizedNumber(thread.contactPhone) == normalizedPhone
        }

        if let normalizedFromNumber {
            return matches.first { normalizedNumber($0.preferredFromNumber) == normalizedFromNumber } ?? matches.first
        }

        return matches.first
    }

    private var resolvedRecipients: [MobileContactSearchResult] {
        if !selectedRecipients.isEmpty {
            return selectedRecipients
        }

        guard !trimmedRecipientQuery.isEmpty else { return [] }
        return [rawRecipientSuggestion]
    }

    private var isComposingGroup: Bool {
        resolvedRecipients.count > 1
    }

    private var groupRuleMessage: String? {
        validationMessage(for: resolvedRecipients)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RotaryBackdrop(onTap: { RotaryKeyboard.dismiss() })

            VStack(spacing: 12) {
                recipientSection
                    .padding(.horizontal, 12)
                    .padding(.top, 12)

                    if let groupRuleMessage {
                        Text(groupRuleMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                    } else if isComposingGroup {
                        Text("Group draft: \(resolvedRecipients.count) recipients")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                    }

                    if let existingThreadPreview {
                        previewCard(existingThreadPreview)
                            .padding(.horizontal, 12)
                    }

                    if !suggestions.isEmpty || canShowRawRecipientSuggestion {
                        suggestionsList
                            .padding(.horizontal, 12)
                    }

                    if isSearching {
                        RotarySkeletonList(rows: 2, showTimestamp: false)
                            .padding(.top, 4)
                    }

                Spacer()

                    if let errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboard()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    RotaryGlassIcon(
                        systemName: "xmark",
                        size: 15,
                        frameSize: 34,
                        shape: .circle,
                        showsBackground: false
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
        }
        }
        .safeAreaInset(edge: .bottom) {
            composeBar
        }
        .sheet(isPresented: $showingCreateContact) {
            RotaryCreateContactSheet(
                initialName: nil,
                initialPhoneNumber: trimmedRecipientQuery,
                initialEmail: nil,
                store: store
            ) { contact in
                if let phoneNumber = contact.phone {
                    selectedRecipients.append(
                        MobileContactSearchResult(
                            id: contact.id,
                            kind: "contact",
                            name: contact.name,
                            phoneNumber: phoneNumber,
                            subtitle: contact.email ?? phoneNumber
                        )
                    )
                    recipientQuery = ""
                    suggestions = []
                }
            }
        }
        .task(id: recipientQuery) {
            await searchRecipients()
        }
        .task {
            if selectedFromNumber.isEmpty {
                selectedFromNumber = initialFromNumber
            }
            if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !initialMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                message = initialMessage
            }
        }
    }

    private var recipientSection: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("To:")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                if !selectedRecipients.isEmpty {
                    recipientChips
                }

                TextField(
                    "",
                    text: $recipientQuery,
                    prompt: Text("Name or number").foregroundStyle(RotaryTheme.placeholderText)
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.default)
                .submitLabel(.next)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showingCreateContact = true
            } label: {
                RotaryGlassIcon(systemName: "plus", size: 20, frameSize: 46)
                    .foregroundStyle(canShowRawRecipientSuggestion ? RotaryTheme.accent : Color.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var recipientChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selectedRecipients) { recipient in
                    HStack(spacing: 8) {
                        Text(recipient.name)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Button {
                            selectedRecipients.removeAll { $0.id == recipient.id }
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
        }
    }

    private var suggestionsList: some View {
        VStack(spacing: 0) {
            if canShowRawRecipientSuggestion {
                Button {
                    RotaryHaptics.selection()
                    dismissKeyboard()
                    addRecipient(rawRecipientSuggestion)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.bubble.fill")
                            .foregroundStyle(RotaryTheme.accent)
                            .frame(width: 24, height: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rawRecipientSuggestion.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            if let subtitle = rawRecipientSuggestion.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.plain)

                if !suggestions.isEmpty {
                    Divider()
                        .padding(.leading, 50)
                }
            }

            ForEach(suggestions) { suggestion in
                Button {
                    RotaryHaptics.selection()
                    dismissKeyboard()
                    addRecipient(suggestion)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: rotarySuggestionIcon(for: suggestion.kind))
                            .foregroundStyle(RotaryTheme.accent)
                            .frame(width: 24, height: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            if let subtitle = suggestion.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        if let phoneNumber = suggestion.phoneNumber {
                            Text(phoneNumber)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.plain)

                if suggestion.id != suggestions.last?.id {
                    Divider()
                        .padding(.leading, 50)
                }
            }
        }
        .background(RotaryTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
        )
    }

    private func previewCard(_ thread: MobileThreadSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(thread.contactName)
                .font(.body.weight(.semibold))
            Text(rotarySanitizedConversationPreview(thread.preview))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RotaryTheme.incomingBubble, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
        )
    }

    private var composeBar: some View {
        RotaryComposerBar(
            text: $message,
            placeholder: "",
            isWorking: false,
            showsMenu: true,
            onMic: nil,
            onSend: {
                Task { await send() }
            }
        ) {
            Button("Camera", systemImage: "camera.fill") {}
            Button("Photos", systemImage: "photo.on.rectangle") {}
            Button("Audio", systemImage: "waveform") {}
            Button("Send Later", systemImage: "clock.badge") {}
            Button("Create Image", systemImage: "sparkles.rectangle.stack") {}
            Button("Add Files", systemImage: "paperclip") {}
        }
    }

    private func addRecipient(_ recipient: MobileContactSearchResult) {
        if selectedRecipients.contains(where: { existing in
            existing.id == recipient.id || rotaryCanonicalPhone(existing.phoneNumber ?? existing.name) == rotaryCanonicalPhone(recipient.phoneNumber ?? recipient.name)
        }) {
            recipientQuery = ""
            suggestions = []
            return
        }

        let proposed = selectedRecipients + [recipient]
        if let message = validationMessage(for: proposed) {
            errorMessage = message
            return
        }

        selectedRecipients = proposed
        recipientQuery = ""
        suggestions = []
        errorMessage = nil
    }

    private func validationMessage(for recipients: [MobileContactSearchResult]) -> String? {
        guard recipients.count > 1 else { return nil }
        let agentRecipients = recipients.filter(isAgentRecipient)
        guard !agentRecipients.isEmpty else { return nil }

        if agentRecipients.count == recipients.count {
            return "AI agents cannot be in a group chat with each other."
        }
        return "AI agents cannot be added to regular group chats."
    }

    private func isAgentRecipient(_ recipient: MobileContactSearchResult) -> Bool {
        let normalizedKind = recipient.kind
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalizedKind == "agent" {
            return true
        }

        guard let recipientNumber = rotaryCanonicalPhone(recipient.phoneNumber ?? recipient.name) else {
            return false
        }
        return knownAgentPhoneNumbers.contains(recipientNumber)
    }

    private func searchRecipients() async {
        let query = trimmedRecipientQuery
        guard !query.isEmpty else {
            suggestions = []
            isSearching = false
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            let results = try await store.searchContacts(query: query)
            guard trimmedRecipientQuery == query else { return }
            suggestions = results
        } catch {
            if !Task.isCancelled {
                suggestions = []
            }
        }
    }

    private func send() async {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        dismissKeyboard()

        let recipients = resolvedRecipients
        guard !recipients.isEmpty else {
            errorMessage = "Enter a recipient first."
            return
        }

        if let validationMessage = validationMessage(for: recipients) {
            errorMessage = validationMessage
            return
        }

        for recipient in recipients {
            let normalizedKind = recipient.kind
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let resolvedContactID = (normalizedKind == "contact" || normalizedKind == "group")
                ? recipient.id
                : nil
            let resolvedPhoneNumber = recipient.phoneNumber ?? recipient.name.nonEmptyTrimmed

            guard resolvedContactID != nil || resolvedPhoneNumber != nil else {
                continue
            }

            Task {
                await store.sendMessage(
                    to: resolvedPhoneNumber,
                    contactName: recipient.name,
                    contactId: resolvedContactID,
                    fromNumber: selectedFromNumber.isEmpty ? initialFromNumber : selectedFromNumber,
                    message: trimmedMessage
                )
            }
        }

        RotaryHaptics.success()
        dismiss()
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func normalizedNumber(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct RotaryCreateContactSheet: View {
    let initialName: String?
    let initialPhoneNumber: String?
    let initialEmail: String?
    let store: MessagesStore
    let onCreate: (MobileCreatedContact) -> Void

    var body: some View {
        RotaryContactEditorScreen(
            title: "New Contact",
            initialDraft: initialDraft,
            onSave: { draft in
                try await store.createContact(
                    name: draft.resolvedName,
                    phoneNumber: draft.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: draft.email.nonEmptyTrimmed,
                    company: draft.company.nonEmptyTrimmed,
                    fullAddress: draft.fullAddress.nonEmptyTrimmed,
                    avatarURL: draft.avatarDataURL
                )
            },
            onSaved: onCreate
        )
    }

    private var initialDraft: RotaryContactDraft {
        let parts = (initialName ?? "")
            .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)

        return RotaryContactDraft(
            contactId: nil,
            firstName: parts.first.map(String.init) ?? "",
            lastName: parts.count > 1 ? String(parts[1]) : "",
            company: "",
            phoneNumber: initialPhoneNumber ?? "",
            email: initialEmail ?? "",
            fullAddress: "",
            avatarDataURL: nil
        )
    }
}

private struct RotaryThreadInfoOverlay: View {
    let thread: MobileThreadSummary
    let detail: MobileThreadDetail?
    let store: MessagesStore
    let fromNumber: String
    let startCall: (_ phoneNumber: String, _ fromNumber: String?) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .overlay(Color.white.opacity(0.16))
                .overlay(Color.black.opacity(0.26))
                .ignoresSafeArea()

            NavigationStack {
                RotaryThreadInfoScreen(
                    thread: thread,
                    detail: detail,
                    store: store,
                    fromNumber: fromNumber,
                    startCall: startCall,
                    onClose: onClose,
                    usesEmbeddedBackdrop: false
                )
            }
            .background(Color.clear)
        }
    }
}

private struct RotaryThreadInfoScreen: View {
    private struct EditContactRoute: Identifiable {
        let id: String
    }

    let thread: MobileThreadSummary
    let detail: MobileThreadDetail?
    let store: MessagesStore
    let fromNumber: String
    let startCall: (_ phoneNumber: String, _ fromNumber: String?) -> Void
    var onClose: (() -> Void)? = nil
    var usesEmbeddedBackdrop = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selectedTab = RotaryThreadInfoTab.info
    @State private var editContactRoute: EditContactRoute?
    @State private var showingMessageSheet = false
    @State private var editedContact: MobileCreatedContact?
    @State private var updatedContactLanguage: String?
    @State private var isUpdatingLanguage = false
    @State private var showingLeaveGroupConfirmation = false
    @State private var isLeavingGroup = false

    private var resolvedName: String {
        editedContact?.name.nonEmptyTrimmed ?? detail?.contact.name.nonEmptyTrimmed ?? thread.contactName
    }

    private var resolvedPhone: String? {
        editedContact?.phone?.nonEmptyTrimmed ?? detail?.contact.phone?.nonEmptyTrimmed ?? thread.contactPhone
    }

    private var resolvedEmail: String? {
        editedContact?.email?.nonEmptyTrimmed ?? detail?.contact.email?.nonEmptyTrimmed ?? thread.contactEmail
    }

    private var resolvedCompany: String? {
        editedContact?.company?.nonEmptyTrimmed ?? detail?.contact.company?.nonEmptyTrimmed
    }

    private var resolvedAddress: String? {
        editedContact?.fullAddress?.nonEmptyTrimmed ?? detail?.contact.fullAddress?.nonEmptyTrimmed
    }

    private var resolvedAvatarURL: String? {
        editedContact?.avatarUrl ?? detail?.contact.avatarUrl
    }

    private var resolvedContactLanguage: String? {
        updatedContactLanguage ?? detail?.contact.contactLanguage ?? thread.contactLanguage
    }

    private var resolvedUserLanguage: String? {
        detail?.contact.userLanguage ?? thread.userLanguage
    }

    private var tabItems: [RotaryProfileTabItem] {
        RotaryThreadInfoTab.allCases.map { RotaryProfileTabItem(id: $0.rawValue, title: $0.title) }
    }

    private var participantTitles: [String] {
        let modelParticipants = rotaryThreadParticipantTitles(
            for: thread,
            detail: detail,
            ownerLineNumber: fromNumber
        )
        if modelParticipants.count > 1 {
            return modelParticipants
        }
        let editedParticipants = rotaryConversationHeaderParticipants(from: resolvedName)
        return editedParticipants.count > 1 ? editedParticipants : modelParticipants
    }

    private var isGroupConversation: Bool {
        rotaryThreadIsGroupConversation(
            for: thread,
            detail: detail,
            ownerLineNumber: fromNumber,
            fallbackDisplayName: resolvedName
        )
    }

    private var editableContactID: String? {
        guard !isGroupConversation else { return nil }
        return detail?.contact.id.nonEmptyTrimmed ?? thread.contactId.nonEmptyTrimmed
    }

    private var files: [RotaryThreadAssetItem] {
        rotaryThreadAssetItems(from: detail).filter { $0.category == .file }
    }

    private var photos: [RotaryThreadAssetItem] {
        rotaryThreadAssetItems(from: detail).filter { $0.category == .photo }
    }

    private var links: [RotaryThreadAssetItem] {
        rotaryThreadAssetItems(from: detail).filter { $0.category == .link }
    }

    private var locations: [RotaryThreadLocationItem] {
        rotaryThreadLocationItems(from: detail, editedContact: editedContact)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                RotaryProfileTabBar(
                    items: tabItems,
                    selectedID: Binding(
                        get: { selectedTab.rawValue },
                        set: { selectedTab = RotaryThreadInfoTab(rawValue: $0) ?? .info }
                    )
                )
                .padding(.horizontal, 10)

                currentTabBody
            }
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(
            Group {
                if usesEmbeddedBackdrop {
                    RotaryBackdrop()
                } else {
                    Color.clear
                }
            }
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if let onClose {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClose) {
                        RotaryGlassIcon(systemName: "chevron.left", size: 13, frameSize: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    guard let editableContactID else { return }
                    editContactRoute = EditContactRoute(id: editableContactID)
                }
                .disabled(editableContactID == nil)
            }
        }
        .sheet(item: $editContactRoute) { route in
            RotaryContactEditorScreen(
                title: "Edit Contact",
                initialDraft: editDraft,
                onSave: { draft in
                    try await store.updateContact(
                        contactId: route.id,
                        name: draft.resolvedName,
                        phoneNumber: draft.phoneNumber.nonEmptyTrimmed,
                        email: draft.email.nonEmptyTrimmed,
                        company: draft.company.nonEmptyTrimmed,
                        fullAddress: draft.fullAddress.nonEmptyTrimmed,
                        avatarURL: draft.avatarDataURL
                    )
                },
                onSaved: { contact in
                    editedContact = contact
                    Task {
                        await store.refreshInbox(forceRefresh: true)
                    }
                }
            )
        }
        .sheet(isPresented: $showingMessageSheet) {
            if let resolvedPhone {
                ProxyMessageSheet(
                    fromNumber: fromNumber,
                    initialToNumber: resolvedPhone,
                    messagesStore: store
                )
            }
        }
        .confirmationDialog(
            "Leave this group?",
            isPresented: $showingLeaveGroupConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave Group", role: .destructive) {
                Task { await leaveGroupConversation() }
            }
            .disabled(isLeavingGroup)

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will stop receiving new messages in this group.")
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            RotaryProfileHero(
                title: resolvedName,
                subtitle: resolvedPhone,
                tertiaryText: resolvedEmail,
                imageURL: resolvedAvatarURL
            ) {
                HStack(alignment: .center, spacing: 18) {
                    if let resolvedPhone {
                        RotaryProfileActionButton(title: "Call", systemImage: "phone.fill") {
                            startCall(resolvedPhone, fromNumber)
                        }
                    }

                    if resolvedPhone != nil {
                        RotaryProfileActionButton(title: "Message", systemImage: "bubble.left.fill") {
                            showingMessageSheet = true
                        }
                    }

                    if let resolvedEmail {
                        RotaryProfileActionButton(title: "Email", systemImage: "envelope.fill") {
                            guard let url = URL(string: "mailto:\(resolvedEmail)") else { return }
                            openURL(url)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 18)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var currentTabBody: some View {
        switch selectedTab {
        case .info:
            VStack(spacing: 16) {
                RotaryProfileInfoCard(title: "Contact") {
                    if let resolvedPhone {
                        RotaryProfileMetaRow(label: "mobile", value: resolvedPhone)
                    }

                    if let resolvedEmail {
                        Divider()
                        RotaryProfileMetaRow(label: "email", value: resolvedEmail)
                    }

                    if let resolvedCompany {
                        Divider()
                        RotaryProfileMetaRow(label: "company", value: resolvedCompany)
                    }

                    if let resolvedAddress {
                        Divider()
                        RotaryProfileMetaRow(label: "address", value: resolvedAddress)
                    }

                    if let website = detail?.contact.website?.nonEmptyTrimmed {
                        Divider()
                        Button {
                            if let url = URL(string: website) {
                                openURL(url)
                            }
                        } label: {
                            RotaryProfileMetaRow(label: "website", value: website, valueColor: RotaryTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let socials = detail?.contact.socialProfiles, !socials.isEmpty {
                    RotaryProfileInfoCard(title: "Social") {
                        ForEach(Array(socials.enumerated()), id: \.element.id) { index, social in
                            if index > 0 {
                                Divider()
                            }

                            Button {
                                if let url = URL(string: social.url) {
                                    openURL(url)
                                }
                            } label: {
                                RotaryProfileMetaRow(label: social.label.lowercased(), value: social.url, valueColor: RotaryTheme.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                RotaryProfileInfoCard(title: "Conversation") {
                    RotaryProfileMetaRow(label: "your line", value: fromNumber)

                    Divider()
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        Text("language")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 88, alignment: .leading)

                        Menu {
                            ForEach(threadLanguageOptions, id: \.code) { option in
                                Button(option.title) {
                                    Task { await setContactLanguage(option.code) }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(languageDisplayName(resolvedContactLanguage) ?? "Auto")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                if isUpdatingLanguage {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .disabled(isUpdatingLanguage)
                        .buttonStyle(.plain)
                    }

                    if let resolvedUserLanguage {
                        Divider()
                        RotaryProfileMetaRow(
                            label: "your locale",
                            value: languageDisplayName(resolvedUserLanguage) ?? resolvedUserLanguage.uppercased()
                        )
                    }

                    if let lastMessageAt = thread.lastMessageAt {
                        Divider()
                        RotaryProfileMetaRow(
                            label: "last message",
                            value: RotaryDateFormatting.listTimestamp(lastMessageAt)
                        )
                    }

                    if let summary = detail?.contact.lastActivitySummary?.nonEmptyTrimmed {
                        Divider()
                        RotaryProfileMetaRow(label: "latest", value: summary)
                    }
                }

                if isGroupConversation {
                    RotaryProfileInfoCard(title: "Participants") {
                        ForEach(Array(participantTitles.enumerated()), id: \.offset) { index, participant in
                            if index > 0 {
                                Divider()
                            }
                            RotaryProfileMetaRow(label: "member \(index + 1)", value: participant)
                        }

                        Divider()
                        Button(role: .destructive) {
                            showingLeaveGroupConfirmation = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Leave Group")
                                    .font(.subheadline.weight(.semibold))
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(.red)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLeavingGroup)
                    }
                }
            }
            .padding(.horizontal, 16)
        case .files:
            rotaryAssetListBody(items: files, emptyTitle: "No files yet", emptyIcon: "doc")
        case .photos:
            rotaryPhotoGridBody
        case .links:
            rotaryAssetListBody(items: links, emptyTitle: "No links yet", emptyIcon: "link")
        case .locations:
            rotaryLocationListBody
        }
    }

    private func rotaryAssetListBody(items: [RotaryThreadAssetItem], emptyTitle: String, emptyIcon: String) -> some View {
        VStack(spacing: 12) {
            if items.isEmpty {
                RotaryProfilePlaceholderCard(title: emptyTitle, systemImage: emptyIcon)
            } else {
                ForEach(items) { item in
                    RotaryGlassCard {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(RotaryTheme.softSurface)
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Image(systemName: item.systemImage)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(RotaryTheme.accent)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.body.weight(.semibold))
                                    .lineLimit(2)
                                Text(item.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer(minLength: 8)

                            if let urlString = item.urlString, let url = URL(string: urlString) {
                                Button {
                                    openURL(url)
                                } label: {
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(RotaryTheme.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var rotaryPhotoGridBody: some View {
        Group {
            if photos.isEmpty {
                RotaryProfilePlaceholderCard(title: "No photos yet", systemImage: "photo.on.rectangle")
                    .padding(.horizontal, 16)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(photos) { item in
                        RotaryThreadPhotoTile(item: item)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var rotaryLocationListBody: some View {
        VStack(spacing: 12) {
            if locations.isEmpty {
                RotaryProfilePlaceholderCard(title: "No saved locations", systemImage: "mappin.and.ellipse")
            } else {
                ForEach(locations) { location in
                    RotaryGlassCard {
                        HStack(alignment: .top, spacing: 14) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(RotaryTheme.softSurface)
                                .frame(width: 74, height: 74)
                                .overlay(
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 26, weight: .medium))
                                        .foregroundStyle(.red)
                                )

                            VStack(alignment: .leading, spacing: 6) {
                                Text(location.title)
                                    .font(.body.weight(.semibold))
                                Text(location.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(4)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var editDraft: RotaryContactDraft {
        let nameParts = resolvedName.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)

        return RotaryContactDraft(
            contactId: detail?.contact.id ?? thread.contactId,
            firstName: nameParts.first.map(String.init) ?? "",
            lastName: nameParts.count > 1 ? String(nameParts[1]) : "",
            company: resolvedCompany ?? "",
            phoneNumber: resolvedPhone ?? "",
            email: resolvedEmail ?? "",
            fullAddress: resolvedAddress ?? "",
            avatarDataURL: resolvedAvatarURL
        )
    }

    private var threadLanguageOptions: [(code: String?, title: String)] {
        [
            (nil, "Auto"),
            ("en", "English"),
            ("ko", "Korean"),
            ("es", "Spanish"),
            ("zh", "Chinese"),
            ("ja", "Japanese"),
            ("vi", "Vietnamese"),
            ("tl", "Tagalog"),
        ]
    }

    private func setContactLanguage(_ code: String?) async {
        guard !isUpdatingLanguage else { return }
        isUpdatingLanguage = true
        defer { isUpdatingLanguage = false }

        do {
            try await store.updateThreadLanguage(
                contactId: detail?.contact.id ?? thread.contactId,
                contactLanguage: code
            )
            updatedContactLanguage = code
            await store.refreshThread(
                contactId: thread.contactId,
                fromNumber: fromNumber,
                forceRefresh: true
            )
        } catch {
            // Keep the existing value rendered and rely on regular error surfaces.
        }
    }

    private func leaveGroupConversation() async {
        guard !isLeavingGroup else { return }
        isLeavingGroup = true
        defer { isLeavingGroup = false }

        await store.performThreadAction(contactIds: [thread.contactId], action: "leave_group")
        await store.refreshInbox(forceRefresh: true)
        dismiss()
    }

    private func languageDisplayName(_ code: String?) -> String? {
        guard let code = code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !code.isEmpty else {
            return nil
        }

        if let localized = Locale.current.localizedString(forLanguageCode: code),
           !localized.isEmpty {
            return localized.capitalized
        }
        return code.uppercased()
    }
}

private enum RotaryThreadInfoTab: String, CaseIterable {
    case info
    case files
    case photos
    case links
    case locations

    var title: String {
        rawValue.capitalized
    }
}

private enum RotaryThreadAssetCategory {
    case file
    case photo
    case link
}

private struct RotaryThreadAssetItem: Identifiable, Hashable {
    let id: String
    let category: RotaryThreadAssetCategory
    let title: String
    let subtitle: String
    let urlString: String?
    let systemImage: String
}

private struct RotaryThreadLocationItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
}

private struct RotaryThreadPhotoTile: View {
    let item: RotaryThreadAssetItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(RotaryTheme.softSurface)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let urlString = item.urlString,
                       let url = URL(string: urlString),
                       let scheme = url.scheme?.lowercased(),
                       scheme == "http" || scheme == "https" {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case let .success(image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                Image(systemName: "photo")
                                    .font(.system(size: 26, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.6)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(item.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .padding(10)
        }
        .clipped()
    }
}

private func rotaryThreadAssetItems(from detail: MobileThreadDetail?) -> [RotaryThreadAssetItem] {
    guard let detail else { return [] }

    var seen = Set<String>()
    var items: [RotaryThreadAssetItem] = []

    for message in detail.messages {
        let timestamp = RotaryDateFormatting.listTimestamp(message.sentAt)
        let context = message.content.nonEmptyTrimmed ?? timestamp
        let payloadStrings = rotaryThreadFlattenedStrings(message.rawPayload)

        let urlValues = Set(
            rotaryThreadURLs(in: message.content).map(\.absoluteString)
            + payloadStrings.compactMap { keyPath, value in
                guard rotaryThreadLooksLikeURL(value) else { return nil }
                return "\(keyPath)|\(value)"
            }
        )

        for rawValue in urlValues {
            let pieces = rawValue.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            let keyPath = pieces.count == 2 ? String(pieces[0]) : ""
            let urlString = pieces.count == 2 ? String(pieces[1]) : String(rawValue)
            guard seen.insert(urlString).inserted else { continue }

            let category = rotaryThreadAssetCategory(urlString: urlString, keyPath: keyPath)
            let title = rotaryThreadAssetTitle(for: urlString)
            items.append(
                RotaryThreadAssetItem(
                    id: urlString,
                    category: category,
                    title: title,
                    subtitle: context,
                    urlString: urlString,
                    systemImage: rotaryThreadAssetSymbol(for: category)
                )
            )
        }
    }

    return items
}

private func rotaryThreadLocationItems(
    from detail: MobileThreadDetail?,
    editedContact: MobileCreatedContact?
) -> [RotaryThreadLocationItem] {
    var locations: [RotaryThreadLocationItem] = []
    var seen = Set<String>()

    let primaryAddress = editedContact?.fullAddress?.nonEmptyTrimmed ?? detail?.contact.fullAddress?.nonEmptyTrimmed
    let cityName = detail?.contact.cityName?.nonEmptyTrimmed

    if let primaryAddress, seen.insert(primaryAddress).inserted {
        locations.append(
            RotaryThreadLocationItem(
                id: "address:\(primaryAddress)",
                title: "Primary",
                subtitle: primaryAddress
            )
        )
    }

    if let cityName, seen.insert(cityName).inserted {
        locations.append(
            RotaryThreadLocationItem(
                id: "city:\(cityName)",
                title: "Area",
                subtitle: cityName
            )
        )
    }

    for message in detail?.messages ?? [] {
        for (keyPath, value) in rotaryThreadFlattenedStrings(message.rawPayload) {
            let lowerKey = keyPath.lowercased()
            guard lowerKey.contains("address")
                || lowerKey.contains("location")
                || lowerKey.contains("city")
            else {
                continue
            }

            guard let locationValue = value.nonEmptyTrimmed, seen.insert(locationValue).inserted else {
                continue
            }

            locations.append(
                RotaryThreadLocationItem(
                    id: "\(keyPath):\(locationValue)",
                    title: "Message context",
                    subtitle: locationValue
                )
            )
        }
    }

    return locations
}

private func rotaryThreadFlattenedStrings(_ payload: [String: JSONValue]) -> [(String, String)] {
    payload.flatMap { key, value in
        rotaryThreadFlattenedStrings(value, prefix: key)
    }
}

private func rotaryThreadFlattenedStrings(_ value: JSONValue, prefix: String) -> [(String, String)] {
    switch value {
    case let .string(string):
        return [(prefix, string)]
    case let .number(number):
        return [(prefix, String(number))]
    case let .bool(boolean):
        return [(prefix, boolean ? "true" : "false")]
    case let .object(object):
        return object.flatMap { key, nestedValue in
            rotaryThreadFlattenedStrings(nestedValue, prefix: "\(prefix).\(key)")
        }
    case let .array(array):
        return array.enumerated().flatMap { index, nestedValue in
            rotaryThreadFlattenedStrings(nestedValue, prefix: "\(prefix)[\(index)]")
        }
    case .null:
        return []
    }
}

private func rotaryThreadURLs(in text: String) -> [URL] {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
        return []
    }

    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return detector.matches(in: text, options: [], range: range).compactMap(\.url)
}

private func rotaryThreadLooksLikeURL(_ value: String) -> Bool {
    guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else { return false }
    return scheme == "http" || scheme == "https"
}

private func rotaryThreadAssetCategory(urlString: String, keyPath: String) -> RotaryThreadAssetCategory {
    let lowerValue = urlString.lowercased()
    let lowerKey = keyPath.lowercased()

    if lowerKey.contains("image")
        || lowerKey.contains("photo")
        || lowerValue.hasSuffix(".png")
        || lowerValue.hasSuffix(".jpg")
        || lowerValue.hasSuffix(".jpeg")
        || lowerValue.hasSuffix(".gif")
        || lowerValue.hasSuffix(".webp")
        || lowerValue.hasSuffix(".heic") {
        return .photo
    }

    if lowerKey.contains("file")
        || lowerKey.contains("attachment")
        || lowerKey.contains("document")
        || lowerKey.contains("media")
        || lowerValue.hasSuffix(".pdf")
        || lowerValue.hasSuffix(".doc")
        || lowerValue.hasSuffix(".docx")
        || lowerValue.hasSuffix(".txt")
        || lowerValue.hasSuffix(".rtf")
        || lowerValue.hasSuffix(".mp3")
        || lowerValue.hasSuffix(".wav")
        || lowerValue.hasSuffix(".m4a") {
        return .file
    }

    return .link
}

private func rotaryThreadAssetTitle(for urlString: String) -> String {
    guard let url = URL(string: urlString) else { return urlString }
    let lastPathComponent = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
    if !lastPathComponent.isEmpty {
        return lastPathComponent
    }
    return url.host ?? urlString
}

private func rotaryThreadAssetSymbol(for category: RotaryThreadAssetCategory) -> String {
    switch category {
    case .file:
        return "doc"
    case .photo:
        return "photo"
    case .link:
        return "link"
    }
}

private func rotaryLooksLikeNamedSender(_ value: String) -> Bool {
    let containsLetters = value.unicodeScalars.contains { CharacterSet.letters.contains($0) }
    let onlyPhoneLikeCharacters = value.unicodeScalars.allSatisfy {
        CharacterSet.decimalDigits.contains($0) || "+-(). #".unicodeScalars.contains($0)
    }
    return containsLetters && !onlyPhoneLikeCharacters
}

private func rotaryCanonicalPhone(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty else {
        return nil
    }

    let digits = value.filter(\.isNumber)
    guard !digits.isEmpty else { return nil }

    if value.hasPrefix("+") {
        return "+\(digits)"
    }
    if digits.count == 11, digits.hasPrefix("1") {
        return "+\(digits)"
    }
    if digits.count == 10 {
        return "+1\(digits)"
    }
    return "+\(digits)"
}

private func rotaryConversationHeaderParticipants(from title: String) -> [String] {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }
    guard trimmed.contains(",") || trimmed.contains("&") else {
        return [trimmed]
    }

    return trimmed
        .replacingOccurrences(of: " & ", with: ",")
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

private func rotaryThreadParticipantTitles(
    for thread: MobileThreadSummary,
    detail: MobileThreadDetail?,
    ownerLineNumber: String?
) -> [String] {
    let ownerCanonicalPhone = rotaryCanonicalPhone(ownerLineNumber)
    if let participants = detail?.participants, !participants.isEmpty {
        var seen = Set<String>()
        let resolved = participants.compactMap { participant -> String? in
            guard !rotaryIsSelfParticipant(participant, ownerCanonicalPhone: ownerCanonicalPhone) else {
                return nil
            }
            let candidate = participant.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = participant.phoneNumber?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let value = candidate.isEmpty ? fallback : candidate
            guard let value, !value.isEmpty else { return nil }
            let key = value.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return value
        }
        if !resolved.isEmpty {
            return resolved
        }
    }

    let fallback = rotaryConversationHeaderParticipants(from: thread.contactName)
    if !fallback.isEmpty {
        return fallback
    }
    let trimmedName = thread.contactName.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedName.isEmpty ? [] : [trimmedName]
}

private func rotaryThreadIsGroupConversation(
    for thread: MobileThreadSummary,
    detail: MobileThreadDetail?,
    ownerLineNumber: String?,
    fallbackDisplayName: String?
) -> Bool {
    let ownerCanonicalPhone = rotaryCanonicalPhone(ownerLineNumber)
    if let participants = detail?.participants, !participants.isEmpty {
        let memberCount = participants.filter { participant in
            !rotaryIsSelfParticipant(participant, ownerCanonicalPhone: ownerCanonicalPhone)
        }.count
        return memberCount > 1
    }

    let fallbackTitle = fallbackDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        ?? thread.contactName
    return rotaryConversationHeaderParticipants(from: fallbackTitle).count > 1
}

private func rotaryIsSelfParticipant(
    _ participant: MobileThreadParticipant,
    ownerCanonicalPhone: String?
) -> Bool {
    let normalizedKind = participant.kind?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
    if let normalizedKind,
       ["line", "owner", "self", "me", "user", "workspace"].contains(normalizedKind) {
        return true
    }

    if let ownerCanonicalPhone,
       let participantCanonicalPhone = rotaryCanonicalPhone(participant.phoneNumber),
       participantCanonicalPhone == ownerCanonicalPhone {
        return true
    }

    let normalizedName = participant.name
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
    return ["you", "me", "my line", "owner", "self", "myself"].contains(normalizedName)
}

private func rotarySuggestionIcon(for kind: String) -> String {
    switch kind {
    case "agent":
        return "person.2.fill"
    case "recent_call":
        return "phone.fill"
    default:
        return "person.crop.circle.fill"
    }
}

private extension String {
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
