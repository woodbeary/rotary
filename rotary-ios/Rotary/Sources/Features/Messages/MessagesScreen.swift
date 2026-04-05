import SwiftUI

private enum MessageInboxFilter: String, CaseIterable, Identifiable {
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
}

struct MessagesScreen: View {
    let bootstrap: MobileBootstrapReadyState
    let api: RotaryAPIClient
    let tokenProvider: RotaryTokenProvider
    let showSettings: () -> Void
    let startCall: (_ phoneNumber: String, _ fromNumber: String?) -> Void
    let onUnreadCountChange: ((Int) -> Void)?

    @State private var showingCompose = false
    @State private var selectedFilter: MessageInboxFilter = .all
    @State private var searchText = ""
    @State private var loadedThreads: [MobileThreadSummary] = []
    @State private var filterCounts: MobileThreadFilterCounts?
    @State private var selectedThreadIDs = Set<String>()
    @State private var isEditing = false
    @State private var isLoading = false
    @State private var hasAttemptedLoad = false
    @State private var loadError: String?

    init(
        bootstrap: MobileBootstrapReadyState,
        api: RotaryAPIClient,
        tokenProvider: @escaping RotaryTokenProvider,
        showSettings: @escaping () -> Void,
        startCall: @escaping (_ phoneNumber: String, _ fromNumber: String?) -> Void,
        onUnreadCountChange: ((Int) -> Void)? = nil
    ) {
        self.bootstrap = bootstrap
        self.api = api
        self.tokenProvider = tokenProvider
        self.showSettings = showSettings
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

    private var sourceThreads: [MobileThreadSummary] {
        hasAttemptedLoad ? loadedThreads : bootstrap.threadPreview
    }

    private var allThreads: [MobileThreadSummary] {
        sourceThreads.sorted { ($0.lastMessageAt ?? "") > ($1.lastMessageAt ?? "") }
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

    var body: some View {
        NavigationStack {
            ZStack {
                RotaryBackdrop(onTap: { RotaryKeyboard.dismiss() })

                VStack(spacing: 0) {
                    filterStrip
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                        .padding(.bottom, 8)

                    if isLoading && !hasAttemptedLoad {
                        loadingState
                    } else if filteredThreads.isEmpty {
                        emptyState
                    } else {
                        List(filteredThreads) { thread in
                            if isEditing {
                                editableRow(thread)
                            } else {
                                NavigationLink {
                                MessageThreadScreen(
                                    thread: thread,
                                    senderNumbers: senderNumbers,
                                    ownerLine: bootstrap.ownerLine?.phoneNumber ?? bootstrap.capabilities.defaultMainLine,
                                    api: api,
                                    tokenProvider: tokenProvider,
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
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        Task {
                                            await performSingleThreadAction(
                                                (thread.unreadCount ?? 0) > 0 ? "mark_read" : "mark_unread",
                                                thread: thread
                                            )
                                        }
                                    } label: {
                                        Label((thread.unreadCount ?? 0) > 0 ? "Read" : "Unread", systemImage: (thread.unreadCount ?? 0) > 0 ? "envelope.open" : "envelope.badge")
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if thread.isSpam == true {
                                        Button {
                                            Task { await performSingleThreadAction("unmark_spam", thread: thread) }
                                        } label: {
                                            Label("Inbox", systemImage: "tray.and.arrow.down")
                                        }
                                        .tint(.mint)
                                    } else if thread.isDeleted == true {
                                        Button {
                                            Task { await performSingleThreadAction("restore", thread: thread) }
                                        } label: {
                                            Label("Recover", systemImage: "arrow.uturn.backward")
                                        }
                                        .tint(.green)
                                    } else {
                                        Button(role: .destructive) {
                                            Task { await performSingleThreadAction("move_to_deleted", thread: thread) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }

                                        Button {
                                            Task { await performSingleThreadAction("mark_spam", thread: thread) }
                                        } label: {
                                            Label("Spam", systemImage: "exclamationmark.bubble")
                                        }
                                        .tint(.orange)
                                    }
                                }
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
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
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditing ? "Done" : "Edit") {
                        RotaryHaptics.selection()
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isEditing.toggle()
                            if !isEditing {
                                selectedThreadIDs.removeAll()
                            }
                        }
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isEditing {
                        Menu {
                            Button("Select All", systemImage: "checkmark.circle") {
                                selectedThreadIDs = Set(filteredThreads.map(\.contactId))
                            }
                            Button("Deselect All", systemImage: "circle") {
                                selectedThreadIDs.removeAll()
                            }
                            Divider()
                            Button("Mark Read", systemImage: "envelope.open") {
                                Task { await performBulkAction("mark_read") }
                            }
                            Button("Mark Unread", systemImage: "envelope.badge") {
                                Task { await performBulkAction("mark_unread") }
                            }
                            Button(selectedFilter == .deleted ? "Recover" : "Delete", systemImage: selectedFilter == .deleted ? "arrow.uturn.backward" : "trash") {
                                Task { await performBulkAction(selectedFilter == .deleted ? "restore" : "move_to_deleted") }
                            }
                            if selectedFilter == .spam {
                                Button("Move to Inbox", systemImage: "tray.and.arrow.down") {
                                    Task { await performBulkAction("unmark_spam") }
                                }
                            } else if selectedFilter != .deleted {
                                Button("Move to Spam", systemImage: "exclamationmark.bubble") {
                                    Task { await performBulkAction("mark_spam") }
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .disabled(selectedThreadIDs.isEmpty)
                    } else {
                        Button {
                            showingCompose = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }

                        Button(action: showSettings) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCompose, onDismiss: {
                Task { await refreshInbox(forceRefresh: true) }
            }) {
                ComposeMessageSheet(
                    senderNumbers: senderNumbers,
                    initialFromNumber: senderNumbers.first ?? bootstrap.capabilities.defaultMainLine,
                    existingThreads: allThreads,
                    api: api,
                    tokenProvider: tokenProvider
                )
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
        .safeAreaInset(edge: .bottom) {
            if isEditing {
                bulkActionBar
            }
        }
        .task {
            publishUnreadCount(for: sourceThreads)
            await refreshInbox()
        }
        .onChange(of: bootstrap.threadPreview.count) { _, _ in
            publishUnreadCount(for: hasAttemptedLoad ? loadedThreads : bootstrap.threadPreview)
            Task { await refreshInbox(forceRefresh: true) }
        }
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MessageInboxFilter.allCases) { filter in
                    Button {
                        RotaryHaptics.selection()
                        selectedFilter = filter
                    } label: {
                        HStack(spacing: 8) {
                            Text(filter.title)
                            if let count = count(for: filter), count > 0 {
                                Text("\(count)")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(selectedFilter == filter ? Color.white.opacity(0.18) : RotaryTheme.subtleSurface)
                                    )
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedFilter == filter ? Color.white : Color.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selectedFilter == filter ? RotaryTheme.accent : RotaryTheme.softSurface)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var bulkActionBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 10) {
                bulkActionButton("Read", systemImage: "envelope.open") {
                    Task { await performBulkAction("mark_read") }
                }
                bulkActionButton("Unread", systemImage: "envelope.badge") {
                    Task { await performBulkAction("mark_unread") }
                }
                bulkActionButton(selectedFilter == .deleted ? "Recover" : "Delete", systemImage: selectedFilter == .deleted ? "arrow.uturn.backward" : "trash") {
                    Task { await performBulkAction(selectedFilter == .deleted ? "restore" : "move_to_deleted") }
                }
                if selectedFilter == .spam {
                    bulkActionButton("Inbox", systemImage: "tray.and.arrow.down") {
                        Task { await performBulkAction("unmark_spam") }
                    }
                } else if selectedFilter != .deleted {
                    bulkActionButton("Spam", systemImage: "exclamationmark.bubble") {
                        Task { await performBulkAction("mark_spam") }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)
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
            }
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var loadingState: some View {
        RotarySkeletonList(rows: 7)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: selectedFilter == .deleted ? "trash" : "message")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? emptyTitle : "No matching conversations")
                .font(.headline)
            Text(searchText.isEmpty ? emptyMessage : "Search names, numbers, or previews.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let loadError, !loadError.isEmpty {
                Text(loadError)
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
            return "Messages from your real Rotary numbers will appear here."
        case .known:
            return "Conversations with named senders will appear here."
        case .spam:
            return "Unknown and spam conversations live here."
        case .deleted:
            return "Deleted conversations can be recovered here."
        }
    }

    private func count(for filter: MessageInboxFilter) -> Int? {
        switch filter {
        case .all:
            return filterCounts?.all
        case .known:
            return filterCounts?.knownSenders
        case .spam:
            return filterCounts?.spam
        case .deleted:
            return filterCounts?.recentlyDeleted
        }
    }

    private func matchesCurrentFilter(_ thread: MobileThreadSummary) -> Bool {
        switch selectedFilter {
        case .all:
            return thread.isDeleted != true && thread.isSpam != true
        case .known:
            return thread.isDeleted != true && thread.isSpam != true && looksLikeNamedSender(thread.contactName)
        case .spam:
            return thread.isSpam == true
        case .deleted:
            return thread.isDeleted == true
        }
    }

    private func normalizedNumber(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func refreshInbox(forceRefresh: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        async let threadsResult = loadThreadsResult(forceRefresh: forceRefresh)
        async let filtersResult = loadFiltersResult(forceRefresh: forceRefresh)

        let threadLoad = await threadsResult
        let filterLoad = await filtersResult

        switch threadLoad {
        case let .success(threads):
            loadedThreads = threads
            hasAttemptedLoad = true
            loadError = nil
            publishUnreadCount(for: threads)
        case let .failure(error):
            if !loadedThreads.isEmpty {
                hasAttemptedLoad = true
            }
            loadError = error.localizedDescription
            publishUnreadCount(for: hasAttemptedLoad ? loadedThreads : bootstrap.threadPreview)
        }

        switch filterLoad {
        case let .success(filters):
            filterCounts = filters
        case let .failure(error):
            if filterCounts == nil {
                loadError = error.localizedDescription
            }
        }
    }

    private func loadThreadsResult(forceRefresh: Bool = false) async -> Result<[MobileThreadSummary], Error> {
        do {
            let threads = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.listThreads(token: token, forceRefresh: forceRefresh)
            }
            return .success(threads)
        } catch {
            return .failure(error)
        }
    }

    private func loadFiltersResult(forceRefresh: Bool = false) async -> Result<MobileThreadFilterCounts, Error> {
        do {
            let filters = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.messageFilters(token: token, forceRefresh: forceRefresh)
            }
            return .success(filters)
        } catch {
            return .failure(error)
        }
    }

    private func performBulkAction(_ action: String) async {
        let selected = Array(selectedThreadIDs)
        guard !selected.isEmpty else { return }

        do {
            _ = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.updateThreads(token: token, contactIds: selected, action: action)
            }
            RotaryHaptics.success()
            selectedThreadIDs.removeAll()
            await refreshInbox(forceRefresh: true)
        } catch {
            RotaryHaptics.error()
            loadError = error.localizedDescription
        }
    }

    private func performSingleThreadAction(_ action: String, thread: MobileThreadSummary) async {
        selectedThreadIDs = [thread.contactId]
        await performBulkAction(action)
    }

    private func publishUnreadCount(for threads: [MobileThreadSummary]) {
        let unread = threads
            .filter { $0.isDeleted != true && $0.isSpam != true }
            .reduce(0) { partialResult, thread in
                partialResult + max(thread.unreadCount ?? 0, 0)
            }
        onUnreadCountChange?(unread)
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
            .background(RotaryTheme.softSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(selectedThreadIDs.isEmpty)
        .opacity(selectedThreadIDs.isEmpty ? 0.45 : 1)
    }
}

struct MessageThreadScreen: View {
    let thread: MobileThreadSummary
    let senderNumbers: [String]
    let ownerLine: String
    let api: RotaryAPIClient
    let tokenProvider: RotaryTokenProvider
    let startCall: (_ phoneNumber: String, _ fromNumber: String?) -> Void

    @State private var detail: MobileThreadDetail?
    @State private var message = ""
    @State private var selectedFromNumber = ""
    @State private var errorMessage: String?
    @State private var isWorking = false
    @FocusState private var composerFocused: Bool

    private var effectiveFromNumber: String {
        let normalizedSelection = selectedFromNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if senderNumbers.contains(normalizedSelection) {
            return normalizedSelection
        }
        return senderNumbers.first ?? ownerLine
    }

    private var transcriptMessages: [RotaryConversationBubbleModel] {
        (detail?.messages ?? []).map { item in
            RotaryConversationBubbleModel(
                id: item.id,
                direction: item.direction == "outbound" ? .outbound : .inbound,
                text: item.content,
                timestamp: RotaryDateFormatting.messageTimestamp(item.sentAt),
                date: RotaryDateFormatting.parse(item.sentAt),
                statusText: item.direction == "outbound" ? statusText(for: item) : nil
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
                                RotaryConversationTranscriptView(messages: transcriptMessages)
                                    .id(transcriptMessages.count)
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
                        .onChange(of: detail?.messages.count ?? 0) { _, _ in
                            scrollToBottom(proxy: proxy)
                        }
                    }
                } else if isWorking {
                    ProgressView()
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Spacer()
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
            }

            messageComposer
        }
        .navigationTitle(thread.contactName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let phoneNumber = thread.contactPhone {
                    Button {
                        startCall(phoneNumber, effectiveFromNumber)
                    } label: {
                        Image(systemName: "phone.fill")
                    }
                }
            }
        }
        .task {
            await load(markRead: true)
        }
    }

    private var messageComposer: some View {
        VStack(spacing: 6) {
            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
            }

            RotaryComposerBar(
                text: $message,
                placeholder: "Text message",
                maxLines: 1 ... 5,
                isWorking: isWorking,
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

    private func load(markRead: Bool) async {
        isWorking = true
        defer { isWorking = false }

        do {
            let loaded = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.threadDetail(token: token, contactId: thread.contactId)
            }
            detail = loaded
            errorMessage = nil
            if selectedFromNumber.isEmpty {
                let preferredFromNumber = loaded.contact.preferredFromNumber
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                selectedFromNumber = senderNumbers.contains(preferredFromNumber)
                    ? preferredFromNumber
                    : (senderNumbers.first ?? ownerLine)
            }
            if markRead, (thread.unreadCount ?? 0) > 0 {
                _ = try? await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                    try await api.updateThreads(token: token, contactIds: [thread.contactId], action: "mark_read")
                }
            }
        } catch {
            detail = nil
            errorMessage = error.localizedDescription
        }
    }

    private func sendMessage() async {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            _ = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.sendMessage(
                    token: token,
                    contactId: thread.contactId,
                    toNumber: nil,
                    fromNumber: effectiveFromNumber,
                    message: message.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            RotaryHaptics.success()
            message = ""
            await load(markRead: false)
        } catch {
            RotaryHaptics.error()
            errorMessage = error.localizedDescription
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastId = transcriptMessages.last?.id else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }

    private func statusText(for item: MobileThreadMessage) -> String? {
        guard item.direction == "outbound" else { return nil }

        switch item.status.lowercased() {
        case "queued", "sending":
            return "Sending…"
        case "failed":
            return "Not delivered"
        default:
            return "Delivered"
        }
    }
}

private struct ComposeMessageSheet: View {
    @Environment(\.dismiss) private var dismiss

    let senderNumbers: [String]
    let initialFromNumber: String
    let existingThreads: [MobileThreadSummary]
    let api: RotaryAPIClient
    let tokenProvider: RotaryTokenProvider

    @State private var recipientQuery = ""
    @State private var selectedRecipients: [MobileContactSearchResult] = []
    @State private var suggestions: [MobileContactSearchResult] = []
    @State private var message = ""
    @State private var selectedFromNumber = ""
    @State private var errorMessage: String?
    @State private var isWorking = false
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
        return existingThreads.first { $0.contactPhone == phoneNumber }
    }

    private var resolvedPhoneNumbers: [String] {
        let fromSelections = selectedRecipients.compactMap(\.phoneNumber)
        if !fromSelections.isEmpty {
            return Array(NSOrderedSet(array: fromSelections)) as? [String] ?? fromSelections
        }

        let trimmed = recipientQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? [] : [trimmed]
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
            CreateContactSheet(
                initialName: nil,
                initialPhoneNumber: trimmedRecipientQuery,
                initialEmail: nil,
                api: api,
                tokenProvider: tokenProvider
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
                    if !selectedRecipients.contains(where: { $0.id == suggestion.id }) {
                        selectedRecipients.append(suggestion)
                    }
                    recipientQuery = ""
                    suggestions = []
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: icon(for: suggestion.kind))
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
            placeholder: "Text message",
            isWorking: isWorking,
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
        let query = recipientQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            suggestions = []
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(180))
            guard recipientQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query else { return }
            let payload = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.searchContacts(token: token, query: query)
            }
            suggestions = payload.results
        } catch {
            if !Task.isCancelled {
                suggestions = []
            }
        }
    }

    private func send() async {
        isWorking = true
        defer { isWorking = false }

        do {
            for phoneNumber in resolvedPhoneNumbers {
                _ = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                    try await api.sendMessage(
                        token: token,
                        contactId: nil,
                        toNumber: phoneNumber,
                        fromNumber: selectedFromNumber.isEmpty ? initialFromNumber : selectedFromNumber,
                        message: message.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
            }
            RotaryHaptics.success()
            dismiss()
        } catch {
            RotaryHaptics.error()
            errorMessage = error.localizedDescription
        }
    }

    private func icon(for kind: String) -> String {
        switch kind {
        case "agent":
            return "person.2.fill"
        case "recent_call":
            return "phone.fill"
        default:
            return "person.crop.circle.fill"
        }
    }
}

private func looksLikeNamedSender(_ value: String) -> Bool {
    let containsLetters = value.unicodeScalars.contains { CharacterSet.letters.contains($0) }
    let onlyPhoneLikeCharacters = value.unicodeScalars.allSatisfy {
        CharacterSet.decimalDigits.contains($0) || "+-(). #".unicodeScalars.contains($0)
    }
    return containsLetters && !onlyPhoneLikeCharacters
}

private struct CreateContactSheet: View {
    let initialName: String?
    let initialPhoneNumber: String?
    let initialEmail: String?
    let api: RotaryAPIClient
    let tokenProvider: RotaryTokenProvider
    let onCreate: (MobileCreatedContact) -> Void

    var body: some View {
        RotaryContactEditorScreen(
            title: "New Contact",
            initialDraft: initialDraft,
            onSave: saveContact,
            onSaved: onCreate
        )
    }

    @MainActor
    private func saveContact(_ draft: RotaryContactDraft) async throws -> MobileCreatedContact {
        let response: MobileCreatedContactResponse = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token -> MobileCreatedContactResponse in
            try await api.createContact(
                token: token,
                name: draft.resolvedName,
                phoneNumber: draft.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                email: trimmedOptional(draft.email),
                company: trimmedOptional(draft.company),
                fullAddress: trimmedOptional(draft.fullAddress),
                avatarURL: draft.avatarDataURL
            )
        }
        return response.contact
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

    private func trimmedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
