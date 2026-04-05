import SwiftUI

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

struct RotaryMessagesScreen: View {
    let bootstrap: MobileBootstrapReadyState
    let store: MessagesStore
    let startCall: (_ phoneNumber: String, _ fromNumber: String?) -> Void
    let onUnreadCountChange: ((Int) -> Void)?

    @State private var showingCompose = false
    @State private var selectedFilter: RotaryMessageInboxFilter = .all
    @State private var searchText = ""
    @State private var selectedThreadIDs = Set<String>()
    @State private var isEditing = false

    init(
        bootstrap: MobileBootstrapReadyState,
        store: MessagesStore,
        startCall: @escaping (_ phoneNumber: String, _ fromNumber: String?) -> Void,
        onUnreadCountChange: ((Int) -> Void)? = nil
    ) {
        self.bootstrap = bootstrap
        self.store = store
        self.startCall = startCall
        self.onUnreadCountChange = onUnreadCountChange
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

    private var allThreads: [MobileThreadSummary] {
        store.threads
    }

    private var filteredThreads: [MobileThreadSummary] {
        let base = allThreads.filter(matchesCurrentFilter)
        guard !searchText.isEmpty else { return base }
        let query = searchText.lowercased()
        return base.filter { thread in
            [
                thread.contactName.lowercased(),
                thread.preview.lowercased(),
                thread.contactPhone?.lowercased(),
                thread.contactEmail?.lowercased(),
            ]
            .compactMap { $0 }
            .contains(where: { $0.contains(query) })
        }
    }

    private var unreadSignature: String {
        store.threads
            .map { "\($0.contactId):\($0.unreadCount ?? 0):\($0.lastMessageAt ?? "")" }
            .joined(separator: "|")
    }

    private var likelyThreadPrefetchSignature: String {
        filteredThreads
            .prefix(4)
            .map(\.contactId)
            .joined(separator: "|")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RotaryBackdrop(onTap: { RotaryKeyboard.dismiss() })

                VStack(spacing: 0) {
                    inboxHeader

                    if RotaryDebugFlags.forceSkeletonPlaceholders || (store.isRefreshingInbox && filteredThreads.isEmpty) {
                        loadingState
                    } else if filteredThreads.isEmpty {
                        emptyState
                    } else {
                        List(filteredThreads) { thread in
                            if isEditing {
                                editableRow(thread)
                            } else {
                                NavigationLink {
                                    RotaryMessageThreadScreen(
                                        thread: thread,
                                        senderNumbers: senderNumbers,
                                        ownerLine: bootstrap.ownerLine?.phoneNumber ?? bootstrap.capabilities.defaultMainLine,
                                        store: store,
                                        startCall: startCall
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
                                .task {
                                    await store.prefetchThreadIfNeeded(thread)
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
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isEditing {
                    bulkActionBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    RotaryGlassTextButton(title: isEditing ? "Done" : "Edit", action: toggleEditing)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        RotaryGlassIconButton(systemName: "square.and.pencil") {
                            RotaryHaptics.selection()
                            showingCompose = true
                        }

                        Menu {
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
                                Button("Refresh Inbox", systemImage: "arrow.clockwise") {
                                    Task { await store.refreshInbox(forceRefresh: true) }
                                }

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
                                        selectedThreadIDs = Set(filteredThreads.map(\.contactId))
                                    }
                                    Button("Deselect All", systemImage: "circle") {
                                        selectedThreadIDs.removeAll()
                                    }
                                    Divider()
                                    Button("Mark Read", systemImage: "envelope.open") {
                                        Task { await store.performThreadAction(contactIds: Array(selectedThreadIDs), action: "mark_read") }
                                    }
                                    Button("Mark Unread", systemImage: "envelope.badge") {
                                        Task { await store.performThreadAction(contactIds: Array(selectedThreadIDs), action: "mark_unread") }
                                    }
                                    Button(selectedFilter == .deleted ? "Recover" : "Delete", systemImage: selectedFilter == .deleted ? "arrow.uturn.backward" : "trash") {
                                        Task {
                                            await store.performThreadAction(
                                                contactIds: Array(selectedThreadIDs),
                                                action: selectedFilter == .deleted ? "restore" : "move_to_deleted"
                                            )
                                        }
                                    }
                                    if selectedFilter == .spam {
                                        Button("Move to Inbox", systemImage: "tray.and.arrow.down") {
                                            Task { await store.performThreadAction(contactIds: Array(selectedThreadIDs), action: "unmark_spam") }
                                        }
                                    } else if selectedFilter != .deleted {
                                        Button("Move to Spam", systemImage: "exclamationmark.bubble") {
                                            Task { await store.performThreadAction(contactIds: Array(selectedThreadIDs), action: "mark_spam") }
                                        }
                                    }
                                }
                            }
                        } label: {
                            RotaryGlassIcon(systemName: "line.3.horizontal")
                                .accessibilityLabel("Inbox options")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCompose) {
                RotaryComposeMessageSheet(
                    senderNumbers: senderNumbers,
                    initialFromNumber: senderNumbers.first ?? bootstrap.capabilities.defaultMainLine,
                    store: store
                )
            }
        }
        .task {
            publishUnreadCount()
            await store.refreshInbox()
        }
        .task(id: likelyThreadPrefetchSignature) {
            await prefetchLikelyThreads()
        }
        .onChange(of: unreadSignature) { _, _ in
            publishUnreadCount()
        }
    }

    private var inboxHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            RotarySearchField(text: $searchText, prompt: "Search")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

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
                    Task { await store.performThreadAction(contactIds: Array(selectedThreadIDs), action: "mark_read") }
                }
                bulkActionButton("Unread", systemImage: "envelope.badge") {
                    Task { await store.performThreadAction(contactIds: Array(selectedThreadIDs), action: "mark_unread") }
                }
                bulkActionButton(selectedFilter == .deleted ? "Recover" : "Delete", systemImage: selectedFilter == .deleted ? "arrow.uturn.backward" : "trash") {
                    Task {
                        await store.performThreadAction(
                            contactIds: Array(selectedThreadIDs),
                            action: selectedFilter == .deleted ? "restore" : "move_to_deleted"
                        )
                    }
                }
                if selectedFilter == .spam {
                    bulkActionButton("Inbox", systemImage: "tray.and.arrow.down") {
                        Task { await store.performThreadAction(contactIds: Array(selectedThreadIDs), action: "unmark_spam") }
                    }
                } else if selectedFilter != .deleted {
                    bulkActionButton("Spam", systemImage: "exclamationmark.bubble") {
                        Task { await store.performThreadAction(contactIds: Array(selectedThreadIDs), action: "mark_spam") }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background {
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    Rectangle()
                        .fill(RotaryTheme.chromeStroke)
                        .frame(height: 1 / UIScreen.main.scale)
                        .opacity(0.55)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }

    private func editableRow(_ thread: MobileThreadSummary) -> some View {
        Button {
            RotaryHaptics.selection()
            if selectedThreadIDs.contains(thread.contactId) {
                selectedThreadIDs.remove(thread.contactId)
            } else {
                selectedThreadIDs.insert(thread.contactId)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedThreadIDs.contains(thread.contactId) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(selectedThreadIDs.contains(thread.contactId) ? RotaryTheme.accent : .secondary)
                RotaryConversationSummaryRow(
                    title: thread.contactName,
                    preview: thread.preview,
                    timestamp: thread.lastMessageAt.map(RotaryDateFormatting.listTimestamp) ?? "",
                    avatarURL: nil,
                    avatarSize: 50,
                    isUnread: (thread.unreadCount ?? 0) > 0
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

    private var loadingState: some View {
        RotarySkeletonList(rows: 7)
            .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: selectedFilter == .deleted ? "trash" : "message")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? emptyTitle : "No matching conversations")
                .font(.headline)
            Text(searchText.isEmpty ? emptyMessage : "Try a different search.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let inboxError = store.inboxError, !inboxError.isEmpty {
                Text(inboxError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var emptyTitle: String {
        switch selectedFilter {
        case .all:
            return "No conversations yet"
        case .known:
            return "No known senders yet"
        case .spam:
            return "No spam conversations"
        case .deleted:
            return "Nothing deleted"
        }
    }

    private var emptyMessage: String {
        switch selectedFilter {
        case .all:
            return "Your conversations will show up here."
        case .known:
            return "Known senders will show up here."
        case .spam:
            return "Spam and unknown senders show up here."
        case .deleted:
            return "Deleted conversations can be recovered here."
        }
    }

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

    private func prefetchLikelyThreads() async {
        let candidates = Array(filteredThreads.prefix(searchText.isEmpty ? 4 : 6))
        guard !candidates.isEmpty else { return }
        await store.prefetchThreadsIfNeeded(candidates, limit: candidates.count)
    }

    private func normalizedNumber(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
}

struct RotaryMessageThreadScreen: View {
    let thread: MobileThreadSummary
    let senderNumbers: [String]
    let ownerLine: String
    let store: MessagesStore
    let startCall: (_ phoneNumber: String, _ fromNumber: String?) -> Void

    @State private var message = ""
    @State private var selectedFromNumber = ""
    @State private var showingInfo = false
    @FocusState private var composerFocused: Bool

    private var currentThread: MobileThreadSummary {
        store.thread(for: thread.contactId) ?? thread
    }

    private var effectiveFromNumber: String {
        let normalizedSelection = selectedFromNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if senderNumbers.contains(normalizedSelection) {
            return normalizedSelection
        }

        let preferred = store.threadViewState(for: currentThread).preferredFromNumber?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let preferred, senderNumbers.contains(preferred) {
            return preferred
        }

        return senderNumbers.first ?? ownerLine
    }

    private var state: MessagesStore.ThreadViewState {
        store.threadViewState(for: currentThread)
    }

    private var displayedMessages: [DisplayedThreadMessage] {
        state.messages
    }

    private var hasLiveMessages: Bool {
        displayedMessages.contains { !$0.isPreviewPlaceholder }
    }

    private var transcriptMessages: [RotaryConversationBubbleModel] {
        displayedMessages.map { item in
            RotaryConversationBubbleModel(
                id: item.id,
                direction: item.direction == "outbound" ? .outbound : .inbound,
                text: item.content,
                timestamp: RotaryDateFormatting.messageTimestamp(item.sentAt),
                date: RotaryDateFormatting.parse(item.sentAt),
                statusText: statusText(for: item),
                attachments: [],
                isPreviewPlaceholder: item.isPreviewPlaceholder
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RotaryBackdrop(onTap: { composerFocused = false })

                if state.isLoading && !hasLiveMessages {
                    RotaryConversationSkeleton(rows: 5)
                        .padding(.horizontal, 12)
                        .padding(.top, 14)
                } else if displayedMessages.isEmpty {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            composerFocused = false
                        }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 12) {
                                RotaryConversationTranscriptView(messages: transcriptMessages)
                                    .id(displayedMessages.count)
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
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
                        .onChange(of: displayedMessages.count) { _, _ in
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
            }

            composer
        }
        .onDisappear {
            composerFocused = false
        }
        .navigationTitle(currentThread.contactName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    composerFocused = false
                    showingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }

                if let phoneNumber = currentThread.contactPhone {
                    Button {
                        composerFocused = false
                        startCall(phoneNumber, effectiveFromNumber)
                    } label: {
                        Image(systemName: "phone.fill")
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showingInfo) {
            RotaryThreadInfoScreen(
                thread: currentThread,
                detail: store.detail(for: currentThread.contactId),
                store: store,
                fromNumber: effectiveFromNumber,
                startCall: startCall
            )
        }
        .task(id: currentThread.contactId) {
            if selectedFromNumber.isEmpty {
                selectedFromNumber = effectiveFromNumber
            }
            await store.ensureThreadLoaded(currentThread, markRead: true)
            if !senderNumbers.contains(selectedFromNumber) {
                selectedFromNumber = effectiveFromNumber
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 6) {
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
                maxLines: 1 ... 5,
                isWorking: false,
                isFocused: $composerFocused,
                showsMenu: false,
                onMic: nil,
                onSend: {
                    Task { await sendMessage() }
                }
            ) {
                EmptyView()
            }
        }
    }

    private func sendMessage() async {
        let outgoing = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !outgoing.isEmpty else { return }

        message = ""
        RotaryHaptics.softTap()
        await store.sendMessage(in: currentThread, fromNumber: effectiveFromNumber, message: outgoing)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastID = displayedMessages.last?.id else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }

    private func statusText(for item: DisplayedThreadMessage) -> String? {
        guard item.direction == "outbound" else { return nil }
        switch item.deliveryState {
        case .pending:
            return "Sending…"
        case .failed:
            return "Not delivered"
        case .sent:
            return "Delivered"
        }
    }
}

private struct RotaryComposeMessageSheet: View {
    @Environment(\.dismiss) private var dismiss

    let senderNumbers: [String]
    let initialFromNumber: String
    let store: MessagesStore

    @State private var recipientQuery = ""
    @State private var selectedRecipients: [MobileContactSearchResult] = []
    @State private var suggestions: [MobileContactSearchResult] = []
    @State private var message = ""
    @State private var selectedFromNumber = ""
    @State private var errorMessage: String?
    @State private var isSearching = false
    @State private var showingCreateContact = false

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
        return store.existingThread(for: phoneNumber)
    }

    private var resolvedRecipients: [MobileContactSearchResult] {
        if !selectedRecipients.isEmpty {
            return selectedRecipients
        }

        guard !trimmedRecipientQuery.isEmpty else { return [] }
        return [rawRecipientSuggestion]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RotaryBackdrop(onTap: { RotaryKeyboard.dismiss() })

            VStack(spacing: 12) {
                recipientSection
                    .padding(.horizontal, 12)
                    .padding(.top, 12)

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
        .navigationTitle("New Message")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
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
        }
    }

    private var recipientSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("To:")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
                .padding(.top, 4)

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
                RotaryGlassIcon(systemName: "plus", size: 18, frameSize: 38)
                    .foregroundStyle(canShowRawRecipientSuggestion ? RotaryTheme.accent : Color.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RotaryTheme.chromeFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RotaryTheme.chromeStroke, lineWidth: 1)
        )
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
                    selectedRecipients.append(rawRecipientSuggestion)
                    recipientQuery = ""
                    suggestions = []
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
                    if !selectedRecipients.contains(where: { $0.id == suggestion.id }) {
                        selectedRecipients.append(suggestion)
                    }
                    recipientQuery = ""
                    suggestions = []
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
            Text(thread.preview)
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
            showsMenu: false,
            onMic: nil,
            onSend: {
                Task { await send() }
            }
        ) {
            EmptyView()
        }
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
            try await Task.sleep(for: .milliseconds(180))
            guard trimmedRecipientQuery == query else { return }
            suggestions = try await store.searchContacts(query: query)
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

        for recipient in recipients {
            guard let phoneNumber = recipient.phoneNumber ?? recipient.name.nonEmptyTrimmed else {
                continue
            }

            Task {
                await store.sendMessage(
                    to: phoneNumber,
                    contactName: recipient.name,
                    contactId: recipient.kind == "contact" ? recipient.id : nil,
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

private struct RotaryThreadInfoScreen: View {
    let thread: MobileThreadSummary
    let detail: MobileThreadDetail?
    let store: MessagesStore
    let fromNumber: String
    let startCall: (_ phoneNumber: String, _ fromNumber: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selectedTab = RotaryThreadInfoTab.info
    @State private var showingEditContact = false
    @State private var showingMessageSheet = false
    @State private var editedContact: MobileCreatedContact?

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

    private var tabItems: [RotaryProfileTabItem] {
        RotaryThreadInfoTab.allCases.map { RotaryProfileTabItem(id: $0.rawValue, title: $0.title) }
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
        VStack(spacing: 0) {
            header

            RotaryProfileTabBar(
                items: tabItems,
                selectedID: Binding(
                    get: { selectedTab.rawValue },
                    set: { selectedTab = RotaryThreadInfoTab(rawValue: $0) ?? .info }
                )
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 10)

            currentTabBody
        }
        .background(RotaryBackdrop())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showingEditContact = true
                }
            }
        }
        .sheet(isPresented: $showingEditContact) {
            RotaryContactEditorScreen(
                title: "Edit Contact",
                initialDraft: editDraft,
                onSave: { draft in
                    try await store.updateContact(
                        contactId: detail?.contact.id ?? thread.contactId,
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
    }

    private var header: some View {
        VStack(spacing: 14) {
            RotaryProfileHero(
                title: resolvedName,
                subtitle: resolvedPhone,
                tertiaryText: resolvedEmail,
                imageURL: resolvedAvatarURL
            ) {
                HStack(spacing: 18) {
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
            ScrollView {
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
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
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
        ScrollView {
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
            .padding(.bottom, 24)
        }
    }

    private var rotaryPhotoGridBody: some View {
        ScrollView {
            if photos.isEmpty {
                VStack(spacing: 12) {
                    RotaryProfilePlaceholderCard(title: "No photos yet", systemImage: "photo.on.rectangle")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(photos) { item in
                        RotaryThreadPhotoTile(item: item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private var rotaryLocationListBody: some View {
        ScrollView {
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
            .padding(.bottom, 24)
        }
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
