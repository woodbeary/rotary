import Foundation
import Observation

enum MessageDeliveryState: String, Hashable {
    case pending
    case sent
    case failed
}

struct DisplayedThreadMessage: Identifiable, Hashable {
    let id: String
    let direction: String
    let fromNumber: String?
    let toNumber: String?
    let content: String
    let status: String
    let sentAt: String
    let deliveryState: MessageDeliveryState
    let failureReason: String?
    let isPreviewPlaceholder: Bool
}

@MainActor
@Observable
final class MessagesStore {
    struct ThreadViewState: Hashable {
        let messages: [DisplayedThreadMessage]
        let isLoading: Bool
        let errorMessage: String?
        let preferredFromNumber: String?
    }

    private struct PendingMessageRecord: Identifiable, Hashable {
        let id: String
        var threadID: String
        let phoneNumber: String?
        let contactName: String
        let fromNumber: String
        let toNumber: String?
        let content: String
        let createdAt: String
        var deliveryState: MessageDeliveryState
        var failureReason: String?
        var serverMessageID: String?
    }

    private let api: RotaryAPIClient
    private let tokenProvider: RotaryTokenProvider

    private(set) var threads: [MobileThreadSummary]
    private(set) var filterCounts: MobileThreadFilterCounts?
    private(set) var isRefreshingInbox = false
    private(set) var inboxError: String?
    private(set) var threadDetails: [String: MobileThreadDetail] = [:]
    private(set) var threadErrors: [String: String] = [:]
    private(set) var loadingThreadIDs = Set<String>()

    private var pendingMessagesByThread: [String: [PendingMessageRecord]] = [:]

    private static var usesLocalDebugBootstrap: Bool {
#if DEBUG
        ProcessInfo.processInfo.environment["ROTARY_USE_CACHED_BOOTSTRAP_ONLY"] == "1"
            || ProcessInfo.processInfo.arguments.contains("-rotary-use-cached-bootstrap-only")
#else
        false
#endif
    }

    init(
        bootstrap: MobileBootstrapReadyState,
        api: RotaryAPIClient,
        tokenProvider: @escaping RotaryTokenProvider
    ) {
        self.api = api
        self.tokenProvider = tokenProvider
        let initialThreads = Self.sortedThreads(bootstrap.threadPreview)
        self.threads = initialThreads
        self.filterCounts = Self.recomputeFilterCounts(
            from: initialThreads,
            fallbackUnread: initialThreads.reduce(0) { partialResult, thread in
                partialResult + max(thread.unreadCount ?? 0, 0)
            }
        )
    }

    func applyBootstrap(_ bootstrap: MobileBootstrapReadyState) {
        var merged = Dictionary(uniqueKeysWithValues: threads.map { ($0.contactId, $0) })
        for incoming in bootstrap.threadPreview {
            merged[incoming.contactId] = incoming
        }

        threads = Self.sortedThreads(
            merged.values.map { applyLocalPresentation(to: $0) }
        )
        filterCounts = Self.recomputeFilterCounts(
            from: threads,
            fallbackUnread: filterCounts?.unread ?? unreadCount()
        )
    }

    func thread(for contactId: String) -> MobileThreadSummary? {
        threads.first { $0.contactId == contactId }
    }

    func existingThread(for phoneNumber: String) -> MobileThreadSummary? {
        let normalized = Self.normalizedPhone(phoneNumber)
        return threads.first { Self.normalizedPhone($0.contactPhone) == normalized }
    }

    func detail(for contactId: String) -> MobileThreadDetail? {
        threadDetails[contactId]
    }

    func relatedThreads(forPreferredFromNumber phoneNumber: String?) -> [MobileThreadSummary] {
        guard let phoneNumber = Self.normalizedPhone(phoneNumber) else { return [] }
        return threads.filter { Self.normalizedPhone($0.preferredFromNumber) == phoneNumber }
    }

    func unreadCount() -> Int {
        threads
            .filter { $0.isDeleted != true && $0.isSpam != true }
            .reduce(0) { partialResult, thread in
                partialResult + max(thread.unreadCount ?? 0, 0)
            }
    }

    func threadViewState(for thread: MobileThreadSummary) -> ThreadViewState {
        let contactId = thread.contactId
        let detail = threadDetails[contactId]
        let pending = pendingMessagesByThread[contactId] ?? []
        let serverMessages = detail?.messages ?? []

        var messages = serverMessages.map {
            DisplayedThreadMessage(
                id: $0.id,
                direction: $0.direction,
                fromNumber: $0.fromNumber,
                toNumber: $0.toNumber,
                content: $0.content,
                status: $0.status,
                sentAt: $0.sentAt,
                deliveryState: .sent,
                failureReason: nil,
                isPreviewPlaceholder: false
            )
        }

        if messages.isEmpty, let preview = previewPlaceholder(for: thread) {
            messages = [preview]
        }

        let pendingMessages = pending
            .filter { record in
                !serverConfirms(record, serverMessages: serverMessages)
            }
            .map {
                DisplayedThreadMessage(
                    id: $0.id,
                    direction: "outbound",
                    fromNumber: $0.fromNumber,
                    toNumber: $0.toNumber,
                    content: $0.content,
                    status: $0.deliveryState == .failed ? "failed" : "queued",
                    sentAt: $0.createdAt,
                    deliveryState: $0.deliveryState,
                    failureReason: $0.failureReason,
                    isPreviewPlaceholder: false
                )
            }

        let merged = Self.sortedDisplayedMessages(messages + pendingMessages)
        let preferredFromNumber = detail?.contact.preferredFromNumber ?? thread.preferredFromNumber

        return ThreadViewState(
            messages: merged,
            isLoading: loadingThreadIDs.contains(contactId),
            errorMessage: threadErrors[contactId],
            preferredFromNumber: preferredFromNumber
        )
    }

    func refreshInbox(forceRefresh: Bool = false) async {
        if Self.usesLocalDebugBootstrap {
            filterCounts = Self.recomputeFilterCounts(from: threads, fallbackUnread: unreadCount())
            inboxError = nil
            return
        }

        if isRefreshingInbox {
            return
        }

        isRefreshingInbox = true
        defer { isRefreshingInbox = false }

        async let threadsResult = loadThreads(forceRefresh: forceRefresh)
        async let filtersResult = loadFilters(forceRefresh: forceRefresh)

        let loadedThreads = await threadsResult
        let loadedFilters = await filtersResult

        switch loadedThreads {
        case let .success(threads):
            var merged = Dictionary(uniqueKeysWithValues: threads.map { ($0.contactId, $0) })
            for existing in self.threads where pendingMessagesByThread[existing.contactId]?.isEmpty == false {
                merged[existing.contactId] = merged[existing.contactId] ?? existing
            }

            let presented = merged.values.map { applyLocalPresentation(to: $0) }
            self.threads = Self.sortedThreads(presented)
            inboxError = nil
            let likelyThreads = Array(self.threads.prefix(3))
            if !likelyThreads.isEmpty {
                Task(priority: .utility) {
                    await prefetchThreadsIfNeeded(likelyThreads, limit: likelyThreads.count)
                }
            }
        case let .failure(error):
            inboxError = error.localizedDescription
        }

        switch loadedFilters {
        case let .success(filters):
            filterCounts = filters
        case .failure:
            if filterCounts == nil {
                filterCounts = Self.recomputeFilterCounts(from: threads, fallbackUnread: unreadCount())
            }
        }
    }

    func ensureThreadLoaded(_ thread: MobileThreadSummary, markRead: Bool) async {
        if markRead {
            markReadLocally(contactId: thread.contactId)
            if (thread.unreadCount ?? 0) > 0 {
                Task {
                    await syncThreadAction(contactIds: [thread.contactId], action: "mark_read")
                }
            }
        }

        if threadDetails[thread.contactId] != nil || loadingThreadIDs.contains(thread.contactId) {
            return
        }

        await refreshThread(contactId: thread.contactId)
    }

    func prefetchThreadIfNeeded(_ thread: MobileThreadSummary) async {
        guard threadDetails[thread.contactId] == nil,
              !loadingThreadIDs.contains(thread.contactId),
              pendingMessagesByThread[thread.contactId] == nil else {
            return
        }

        await refreshThread(contactId: thread.contactId)
    }

    func prefetchThreadsIfNeeded(_ threads: [MobileThreadSummary], limit: Int = 4) async {
        guard limit > 0 else { return }

        for thread in threads.prefix(limit) {
            await prefetchThreadIfNeeded(thread)
        }
    }

    func refreshThread(contactId: String, forceRefresh: Bool = false) async {
        if Self.usesLocalDebugBootstrap {
            threadErrors.removeValue(forKey: contactId)
            return
        }

        if loadingThreadIDs.contains(contactId) {
            return
        }

        loadingThreadIDs.insert(contactId)
        defer { loadingThreadIDs.remove(contactId) }

        do {
            let detail = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.threadDetail(token: token, contactId: contactId, forceRefresh: forceRefresh)
            }
            threadDetails[contactId] = detail
            threadErrors.removeValue(forKey: contactId)
            reconcileThreadSummary(from: detail, contactId: contactId)
        } catch {
            threadErrors[contactId] = error.localizedDescription
        }
    }

    func sendMessage(
        in thread: MobileThreadSummary,
        fromNumber: String,
        message: String
    ) async {
        await sendMessage(
            threadID: thread.contactId,
            contactId: thread.contactId,
            phoneNumber: thread.contactPhone,
            contactName: thread.contactName,
            fromNumber: fromNumber,
            message: message
        )
    }

    func sendMessage(
        to phoneNumber: String,
        contactName: String?,
        contactId: String?,
        fromNumber: String,
        message: String
    ) async {
        let normalizedPhone = Self.normalizedPhone(phoneNumber) ?? phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = contactId.flatMap { thread(for: $0) } ?? existingThread(for: normalizedPhone)
        let threadID = existing?.contactId ?? contactId ?? "draft:\(normalizedPhone)"
        let resolvedName = existing?.contactName ?? contactName ?? normalizedPhone

        await sendMessage(
            threadID: threadID,
            contactId: contactId,
            phoneNumber: normalizedPhone,
            contactName: resolvedName,
            fromNumber: fromNumber,
            message: message
        )
    }

    func retryMessage(contactId: String, messageID: String) async {
        guard let record = pendingMessagesByThread[contactId]?.first(where: { $0.id == messageID }) else {
            return
        }

        removePendingMessage(id: record.id, threadID: contactId)
        await sendMessage(
            threadID: contactId,
            contactId: record.threadID.hasPrefix("draft:") ? nil : record.threadID,
            phoneNumber: record.phoneNumber,
            contactName: record.contactName,
            fromNumber: record.fromNumber,
            message: record.content
        )
    }

    func performThreadAction(contactIds: [String], action: String) async {
        applyThreadActionLocally(contactIds: contactIds, action: action)
        await syncThreadAction(contactIds: contactIds, action: action)
    }

    func searchContacts(query: String) async throws -> [MobileContactSearchResult] {
        let payload = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
            try await api.searchContacts(token: token, query: query)
        }
        return payload.results
    }

    func createContact(
        name: String?,
        phoneNumber: String,
        email: String?,
        company: String? = nil,
        fullAddress: String? = nil,
        avatarURL: String? = nil
    ) async throws -> MobileCreatedContact {
        let payload = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
            try await api.createContact(
                token: token,
                name: name,
                phoneNumber: phoneNumber,
                email: email,
                company: company,
                fullAddress: fullAddress,
                avatarURL: avatarURL
            )
        }
        return payload.contact
    }

    func updateContact(
        contactId: String,
        name: String?,
        phoneNumber: String?,
        email: String?,
        company: String? = nil,
        fullAddress: String? = nil,
        avatarURL: String? = nil
    ) async throws -> MobileCreatedContact {
        let payload = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
            try await api.updateContact(
                token: token,
                contactId: contactId,
                name: name,
                phoneNumber: phoneNumber,
                email: email,
                company: company,
                fullAddress: fullAddress,
                avatarURL: avatarURL
            )
        }
        return payload.contact
    }

    private func sendMessage(
        threadID: String,
        contactId: String?,
        phoneNumber: String?,
        contactName: String,
        fromNumber: String,
        message: String
    ) async {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }

        let now = Self.timestamp()
        let pending = PendingMessageRecord(
            id: "local-\(UUID().uuidString)",
            threadID: threadID,
            phoneNumber: phoneNumber,
            contactName: contactName,
            fromNumber: fromNumber,
            toNumber: phoneNumber,
            content: trimmedMessage,
            createdAt: now,
            deliveryState: .pending,
            failureReason: nil,
            serverMessageID: nil
        )

        addPendingMessage(pending)
        upsertThreadSummary(
            contactId: threadID,
            contactName: contactName,
            contactPhone: phoneNumber,
            preview: trimmedMessage,
            lastDirection: "outbound",
            lastStatus: "queued",
            lastMessageAt: now,
            preferredFromNumber: fromNumber,
            unreadCount: 0,
            isDeleted: false,
            isSpam: false
        )

        do {
            let response = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.sendMessage(
                    token: token,
                    contactId: contactId,
                    toNumber: contactId == nil ? phoneNumber : nil,
                    fromNumber: fromNumber,
                    message: trimmedMessage
                )
            }

            let resolvedContactId = response.contactId ?? contactId ?? existingThread(for: phoneNumber ?? "")?.contactId ?? threadID

            if resolvedContactId != threadID {
                migrateThread(from: threadID, to: resolvedContactId, phoneNumber: phoneNumber, contactName: contactName)
            }

            updatePendingMessage(
                id: pending.id,
                threadID: resolvedContactId,
                deliveryState: .sent,
                failureReason: nil,
                serverMessageID: response.messageId
            )

            threadErrors.removeValue(forKey: resolvedContactId)

            Task {
                await refreshThread(contactId: resolvedContactId, forceRefresh: true)
            }

            if response.contactId == nil, resolvedContactId.hasPrefix("draft:") {
                Task {
                    await refreshInbox(forceRefresh: true)
                }
            }
        } catch {
            updatePendingMessage(
                id: pending.id,
                threadID: threadID,
                deliveryState: .failed,
                failureReason: error.localizedDescription,
                serverMessageID: nil
            )
            threadErrors[threadID] = error.localizedDescription
        }
    }

    private func loadThreads(forceRefresh: Bool) async -> Result<[MobileThreadSummary], Error> {
        do {
            let threads = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.listThreads(token: token, forceRefresh: forceRefresh)
            }
            return .success(threads)
        } catch {
            return .failure(error)
        }
    }

    private func loadFilters(forceRefresh: Bool) async -> Result<MobileThreadFilterCounts, Error> {
        do {
            let filters = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.messageFilters(token: token, forceRefresh: forceRefresh)
            }
            return .success(filters)
        } catch {
            return .failure(error)
        }
    }

    private func syncThreadAction(contactIds: [String], action: String) async {
        do {
            _ = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.updateThreads(token: token, contactIds: contactIds, action: action)
            }
        } catch {
            inboxError = error.localizedDescription
            await refreshInbox(forceRefresh: true)
            for contactId in contactIds {
                await refreshThread(contactId: contactId, forceRefresh: true)
            }
        }
    }

    private func addPendingMessage(_ pending: PendingMessageRecord) {
        pendingMessagesByThread[pending.threadID, default: []].append(pending)
        sortPendingMessages(for: pending.threadID)
    }

    private func removePendingMessage(id: String, threadID: String) {
        pendingMessagesByThread[threadID]?.removeAll { $0.id == id }
        if pendingMessagesByThread[threadID]?.isEmpty == true {
            pendingMessagesByThread.removeValue(forKey: threadID)
        }
    }

    private func updatePendingMessage(
        id: String,
        threadID: String,
        deliveryState: MessageDeliveryState,
        failureReason: String?,
        serverMessageID: String?
    ) {
        for key in pendingMessagesByThread.keys {
            guard let index = pendingMessagesByThread[key]?.firstIndex(where: { $0.id == id }) else {
                continue
            }

            var record = pendingMessagesByThread[key]![index]
            record.threadID = threadID
            record.deliveryState = deliveryState
            record.failureReason = failureReason
            if let serverMessageID {
                record.serverMessageID = serverMessageID
            }

            pendingMessagesByThread[key]!.remove(at: index)
            pendingMessagesByThread[threadID, default: []].append(record)
            sortPendingMessages(for: threadID)

            if pendingMessagesByThread[key]?.isEmpty == true {
                pendingMessagesByThread.removeValue(forKey: key)
            }
            break
        }
    }

    private func migrateThread(from oldID: String, to newID: String, phoneNumber: String?, contactName: String) {
        if let detail = threadDetails.removeValue(forKey: oldID) {
            threadDetails[newID] = detail
        }

        if let error = threadErrors.removeValue(forKey: oldID) {
            threadErrors[newID] = error
        }

        if let pending = pendingMessagesByThread.removeValue(forKey: oldID) {
            pendingMessagesByThread[newID] = pending.map {
                var mutable = $0
                mutable.threadID = newID
                return mutable
            }
        }

        threads = threads.map { thread in
            guard thread.contactId == oldID else { return thread }
            return MobileThreadSummary(
                contactId: newID,
                contactName: thread.contactName,
                contactPhone: phoneNumber ?? thread.contactPhone,
                contactEmail: thread.contactEmail,
                preview: thread.preview,
                lastDirection: thread.lastDirection,
                lastStatus: thread.lastStatus,
                lastMessageAt: thread.lastMessageAt,
                preferredFromNumber: thread.preferredFromNumber,
                unreadCount: thread.unreadCount,
                isDeleted: thread.isDeleted,
                isSpam: thread.isSpam
            )
        }

        if !threads.contains(where: { $0.contactId == newID }) {
            upsertThreadSummary(
                contactId: newID,
                contactName: contactName,
                contactPhone: phoneNumber,
                preview: pendingMessagesByThread[newID]?.last?.content ?? "",
                lastDirection: "outbound",
                lastStatus: "sent",
                lastMessageAt: pendingMessagesByThread[newID]?.last?.createdAt,
                preferredFromNumber: pendingMessagesByThread[newID]?.last?.fromNumber ?? "",
                unreadCount: 0,
                isDeleted: false,
                isSpam: false
            )
        }
    }

    private func reconcileThreadSummary(from detail: MobileThreadDetail, contactId: String) {
        guard let lastMessage = detail.messages.last else { return }

        upsertThreadSummary(
            contactId: contactId,
            contactName: detail.contact.name,
            contactPhone: detail.contact.phone,
            preview: lastMessage.content,
            lastDirection: lastMessage.direction,
            lastStatus: lastMessage.status,
            lastMessageAt: lastMessage.sentAt,
            preferredFromNumber: detail.contact.preferredFromNumber,
            unreadCount: thread(for: contactId)?.unreadCount ?? 0,
            isDeleted: thread(for: contactId)?.isDeleted ?? false,
            isSpam: thread(for: contactId)?.isSpam ?? false
        )
    }

    private func upsertThreadSummary(
        contactId: String,
        contactName: String,
        contactPhone: String?,
        preview: String,
        lastDirection: String,
        lastStatus: String,
        lastMessageAt: String?,
        preferredFromNumber: String,
        unreadCount: Int?,
        isDeleted: Bool?,
        isSpam: Bool?
    ) {
        let existing = thread(for: contactId)
        let summary = MobileThreadSummary(
            contactId: contactId,
            contactName: contactName,
            contactPhone: contactPhone ?? existing?.contactPhone,
            contactEmail: existing?.contactEmail,
            preview: preview,
            lastDirection: lastDirection,
            lastStatus: lastStatus,
            lastMessageAt: lastMessageAt ?? existing?.lastMessageAt,
            preferredFromNumber: preferredFromNumber.isEmpty ? (existing?.preferredFromNumber ?? "") : preferredFromNumber,
            unreadCount: unreadCount ?? existing?.unreadCount,
            isDeleted: isDeleted ?? existing?.isDeleted,
            isSpam: isSpam ?? existing?.isSpam
        )

        threads.removeAll { $0.contactId == contactId }
        threads.append(summary)
        threads = Self.sortedThreads(threads.map { applyLocalPresentation(to: $0) })
        filterCounts = Self.recomputeFilterCounts(from: threads, fallbackUnread: self.unreadCount())
    }

    private func applyLocalPresentation(to summary: MobileThreadSummary) -> MobileThreadSummary {
        guard let pending = pendingMessagesByThread[summary.contactId]?.sorted(by: { $0.createdAt < $1.createdAt }).last else {
            return summary
        }

        return MobileThreadSummary(
            contactId: summary.contactId,
            contactName: summary.contactName,
            contactPhone: summary.contactPhone,
            contactEmail: summary.contactEmail,
            preview: pending.content,
            lastDirection: "outbound",
            lastStatus: pending.deliveryState.rawValue,
            lastMessageAt: pending.createdAt,
            preferredFromNumber: pending.fromNumber,
            unreadCount: summary.unreadCount,
            isDeleted: summary.isDeleted,
            isSpam: summary.isSpam
        )
    }

    private func previewPlaceholder(for thread: MobileThreadSummary) -> DisplayedThreadMessage? {
        guard !thread.preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return DisplayedThreadMessage(
            id: "preview-\(thread.contactId)",
            direction: thread.lastDirection,
            fromNumber: nil,
            toNumber: thread.contactPhone,
            content: thread.preview,
            status: thread.lastStatus,
            sentAt: thread.lastMessageAt ?? Self.timestamp(),
            deliveryState: .sent,
            failureReason: nil,
            isPreviewPlaceholder: true
        )
    }

    private func serverConfirms(_ record: PendingMessageRecord, serverMessages: [MobileThreadMessage]) -> Bool {
        if let serverMessageID = record.serverMessageID,
           serverMessages.contains(where: { $0.id == serverMessageID }) {
            return true
        }

        return serverMessages.contains { message in
            message.direction == "outbound"
                && message.content == record.content
                && message.fromNumber == record.fromNumber
                && abs((RotaryDateFormatting.parse(message.sentAt) ?? .distantPast).timeIntervalSince(RotaryDateFormatting.parse(record.createdAt) ?? .distantPast)) < 90
        }
    }

    private func sortPendingMessages(for threadID: String) {
        pendingMessagesByThread[threadID]?.sort { $0.createdAt < $1.createdAt }
    }

    private func applyThreadActionLocally(contactIds: [String], action: String) {
        guard !contactIds.isEmpty else { return }

        threads = threads.map { thread in
            guard contactIds.contains(thread.contactId) else { return thread }

            switch action {
            case "mark_read":
                return MobileThreadSummary(
                    contactId: thread.contactId,
                    contactName: thread.contactName,
                    contactPhone: thread.contactPhone,
                    contactEmail: thread.contactEmail,
                    preview: thread.preview,
                    lastDirection: thread.lastDirection,
                    lastStatus: thread.lastStatus,
                    lastMessageAt: thread.lastMessageAt,
                    preferredFromNumber: thread.preferredFromNumber,
                    unreadCount: 0,
                    isDeleted: thread.isDeleted,
                    isSpam: thread.isSpam
                )
            case "mark_unread":
                return MobileThreadSummary(
                    contactId: thread.contactId,
                    contactName: thread.contactName,
                    contactPhone: thread.contactPhone,
                    contactEmail: thread.contactEmail,
                    preview: thread.preview,
                    lastDirection: thread.lastDirection,
                    lastStatus: thread.lastStatus,
                    lastMessageAt: thread.lastMessageAt,
                    preferredFromNumber: thread.preferredFromNumber,
                    unreadCount: max(thread.unreadCount ?? 0, 1),
                    isDeleted: thread.isDeleted,
                    isSpam: thread.isSpam
                )
            case "move_to_deleted":
                return MobileThreadSummary(
                    contactId: thread.contactId,
                    contactName: thread.contactName,
                    contactPhone: thread.contactPhone,
                    contactEmail: thread.contactEmail,
                    preview: thread.preview,
                    lastDirection: thread.lastDirection,
                    lastStatus: thread.lastStatus,
                    lastMessageAt: thread.lastMessageAt,
                    preferredFromNumber: thread.preferredFromNumber,
                    unreadCount: 0,
                    isDeleted: true,
                    isSpam: false
                )
            case "restore":
                return MobileThreadSummary(
                    contactId: thread.contactId,
                    contactName: thread.contactName,
                    contactPhone: thread.contactPhone,
                    contactEmail: thread.contactEmail,
                    preview: thread.preview,
                    lastDirection: thread.lastDirection,
                    lastStatus: thread.lastStatus,
                    lastMessageAt: thread.lastMessageAt,
                    preferredFromNumber: thread.preferredFromNumber,
                    unreadCount: thread.unreadCount,
                    isDeleted: false,
                    isSpam: false
                )
            case "mark_spam":
                return MobileThreadSummary(
                    contactId: thread.contactId,
                    contactName: thread.contactName,
                    contactPhone: thread.contactPhone,
                    contactEmail: thread.contactEmail,
                    preview: thread.preview,
                    lastDirection: thread.lastDirection,
                    lastStatus: thread.lastStatus,
                    lastMessageAt: thread.lastMessageAt,
                    preferredFromNumber: thread.preferredFromNumber,
                    unreadCount: 0,
                    isDeleted: false,
                    isSpam: true
                )
            case "unmark_spam":
                return MobileThreadSummary(
                    contactId: thread.contactId,
                    contactName: thread.contactName,
                    contactPhone: thread.contactPhone,
                    contactEmail: thread.contactEmail,
                    preview: thread.preview,
                    lastDirection: thread.lastDirection,
                    lastStatus: thread.lastStatus,
                    lastMessageAt: thread.lastMessageAt,
                    preferredFromNumber: thread.preferredFromNumber,
                    unreadCount: thread.unreadCount,
                    isDeleted: false,
                    isSpam: false
                )
            default:
                return thread
            }
        }

        filterCounts = Self.recomputeFilterCounts(from: threads, fallbackUnread: unreadCount())
    }

    private func markReadLocally(contactId: String) {
        applyThreadActionLocally(contactIds: [contactId], action: "mark_read")
    }

    private static func sortedThreads(_ threads: [MobileThreadSummary]) -> [MobileThreadSummary] {
        threads.sorted { ($0.lastMessageAt ?? "") > ($1.lastMessageAt ?? "") }
    }

    private static func sortedDisplayedMessages(_ messages: [DisplayedThreadMessage]) -> [DisplayedThreadMessage] {
        messages.sorted { lhs, rhs in
            let lhsDate = RotaryDateFormatting.parse(lhs.sentAt) ?? .distantPast
            let rhsDate = RotaryDateFormatting.parse(rhs.sentAt) ?? .distantPast
            if lhsDate == rhsDate {
                return lhs.id < rhs.id
            }
            return lhsDate < rhsDate
        }
    }

    private static func normalizedPhone(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func recomputeFilterCounts(
        from threads: [MobileThreadSummary],
        fallbackUnread: Int
    ) -> MobileThreadFilterCounts {
        let all = threads.filter { $0.isDeleted != true && $0.isSpam != true }
        let known = all.filter { looksLikeNamedSenderForStore($0.contactName) }
        let spam = threads.filter { $0.isSpam == true }
        let deleted = threads.filter { $0.isDeleted == true }
        let unread = all.reduce(0) { partialResult, thread in
            partialResult + max(thread.unreadCount ?? 0, 0)
        }

        return MobileThreadFilterCounts(
            all: all.count,
            knownSenders: known.count,
            spam: spam.count,
            recentlyDeleted: deleted.count,
            unread: max(unread, fallbackUnread)
        )
    }
}

private func looksLikeNamedSenderForStore(_ value: String) -> Bool {
    let containsLetters = value.unicodeScalars.contains { CharacterSet.letters.contains($0) }
    let onlyPhoneLikeCharacters = value.unicodeScalars.allSatisfy {
        CharacterSet.decimalDigits.contains($0) || "+-(). #".unicodeScalars.contains($0)
    }
    return containsLetters && !onlyPhoneLikeCharacters
}
