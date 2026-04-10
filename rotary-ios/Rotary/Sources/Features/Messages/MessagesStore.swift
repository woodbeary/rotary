import Foundation
import Observation

enum MessageDeliveryState: String, Codable, Hashable {
    case pending
    case sent
    case failed
}

enum ThreadDeliveryReceipt: String, Codable, Hashable {
    case sent
    case delivered
    case read
    case undelivered
}

struct DisplayedThreadMessage: Identifiable, Hashable {
    let id: String
    let direction: String
    let fromNumber: String?
    let toNumber: String?
    let content: String
    let originalContent: String?
    let sourceLanguage: String?
    let targetLanguage: String?
    let translationStatus: String?
    let status: String
    let sentAt: String
    let deliveryState: MessageDeliveryState
    let deliveryReceipt: ThreadDeliveryReceipt?
    let failureReason: String?
    let wasTranslated: Bool
    let isPreviewPlaceholder: Bool
}

@MainActor
@Observable
final class MessagesStore {
    struct TranslationDecisionPrompt: Identifiable, Hashable {
        let id: String
        let threadID: String
        let pendingMessageID: String
        let decisionToken: String
        let message: String
        let sourceLanguage: String?
        let targetLanguage: String?
    }

    struct ThreadViewState: Hashable {
        let messages: [DisplayedThreadMessage]
        let isLoading: Bool
        let errorMessage: String?
        let preferredFromNumber: String?
    }

    private struct PendingMessageRecord: Codable, Identifiable, Hashable {
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
        var translationDecisionToken: String?
        var translationSourceLanguage: String?
        var translationTargetLanguage: String?
        var queuedOperationID: String?
    }

    private let api: RotaryAPIClient
    private let tokenProvider: RotaryTokenProvider
    private let mutationDispatcher: RotaryMutationCommanding

    private(set) var threads: [MobileThreadSummary]
    private(set) var filterCounts: MobileThreadFilterCounts?
    private(set) var isRefreshingInbox = false
    private(set) var inboxError: String?
    private(set) var threadDetails: [String: MobileThreadDetail] = [:]
    private(set) var threadErrors: [String: String] = [:]
    private(set) var loadingThreadIDs = Set<String>()
    private(set) var translationDecisionPrompt: TranslationDecisionPrompt?

    private var pendingMessagesByThread: [String: [PendingMessageRecord]] = [:]

#if DEBUG
    private struct DebugSeedConversation {
        let thread: MobileThreadSummary
        let detail: MobileThreadDetail
    }
#endif

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
        tokenProvider: @escaping RotaryTokenProvider,
        mutationDispatcher: RotaryMutationCommanding = RotaryMutationDispatcher.shared
    ) {
        self.api = api
        self.tokenProvider = tokenProvider
        self.mutationDispatcher = mutationDispatcher
        let loadedPending = Self.loadPersistedPendingMessages()
        let loadedThreadDetails = Self.loadPersistedThreadDetails()
        pendingMessagesByThread = loadedPending
        let initialThreads = Self.sortedThreads(
            bootstrap.threadPreview.isEmpty ? Self.debugSeedThreads(from: bootstrap) : bootstrap.threadPreview
        )
        let pendingByThread = loadedPending
        let presentedThreads = initialThreads.map { summary -> MobileThreadSummary in
            let keyCandidates = [summary.id, summary.contactId]
            guard let pending = keyCandidates
                .compactMap({ pendingByThread[$0]?.sorted(by: { $0.createdAt < $1.createdAt }).last })
                .first else {
                return summary
            }

            return MobileThreadSummary(
                threadId: summary.id,
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
                isSpam: summary.isSpam,
                contactLanguage: summary.contactLanguage,
                userLanguage: summary.userLanguage,
                translationMode: summary.translationMode,
                translationEnabled: summary.translationEnabled
            )
        }
        self.threads = Self.sortedThreads(presentedThreads)
        self.filterCounts = Self.recomputeFilterCounts(
            from: threads,
            fallbackUnread: threads.reduce(0) { partialResult, thread in
                partialResult + max(thread.unreadCount ?? 0, 0)
            }
        )
        self.threadDetails = loadedThreadDetails.merging(Self.debugSeedThreadDetails(from: bootstrap)) { current, _ in current }
    }

    func applyBootstrap(_ bootstrap: MobileBootstrapReadyState) {
        var merged = Dictionary(uniqueKeysWithValues: threads.map { ($0.id, $0) })
        for incoming in bootstrap.threadPreview {
            merged[incoming.id] = incoming
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

    func thread(threadID: String) -> MobileThreadSummary? {
        threads.first { $0.id == threadID }
    }

    func existingThread(for phoneNumber: String) -> MobileThreadSummary? {
        let normalized = Self.normalizedPhone(phoneNumber)
        return threads.first { Self.normalizedPhone($0.contactPhone) == normalized }
    }

    func detail(for contactId: String) -> MobileThreadDetail? {
        if let exactThread = threads.first(where: { $0.id == contactId }) {
            return threadDetails[exactThread.id]
        }
        if let preferredThread = threads.first(where: { $0.contactId == contactId }) {
            return threadDetails[preferredThread.id]
        }
        return nil
    }

    func detail(threadID: String) -> MobileThreadDetail? {
        threadDetails[threadID]
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
        let threadID = thread.id
        let detail = threadDetails[threadID]
        let pending = pendingMessagesByThread[threadID] ?? []
        let serverMessages = detail?.messages ?? []

        let messages = serverMessages.map {
            let displayContentCandidate =
                ($0.renderedContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? $0.renderedContent
                : ($0.displayContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                    ? $0.displayContent
                    : $0.content
            let displayContent = displayContentCandidate ?? $0.content
            let originalContent = ($0.originalContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? $0.originalContent
                : nil
            return DisplayedThreadMessage(
                id: $0.id,
                direction: $0.direction,
                fromNumber: $0.fromNumber,
                toNumber: $0.toNumber,
                content: displayContent,
                originalContent: originalContent == displayContent ? nil : originalContent,
                sourceLanguage: $0.sourceLanguage,
                targetLanguage: $0.targetLanguage,
                translationStatus: $0.translationStatus,
                status: $0.status,
                sentAt: $0.sentAt,
                deliveryState: .sent,
                deliveryReceipt: Self.deliveryReceipt(
                    forStatus: $0.status,
                    deliveryState: .sent,
                    direction: $0.direction
                ),
                failureReason: nil,
                wasTranslated: Self.messageWasTranslated(
                    originalContent: originalContent,
                    renderedContent: displayContent,
                    translationStatus: $0.translationStatus
                ),
                isPreviewPlaceholder: false
            )
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
                    originalContent: nil,
                    sourceLanguage: nil,
                    targetLanguage: nil,
                    translationStatus: nil,
                    status: $0.deliveryState == .failed ? "failed" : "queued",
                    sentAt: $0.createdAt,
                    deliveryState: $0.deliveryState,
                    deliveryReceipt: Self.deliveryReceipt(
                        forStatus: $0.deliveryState == .failed ? "failed" : "queued",
                        deliveryState: $0.deliveryState,
                        direction: "outbound"
                    ),
                    failureReason: $0.failureReason,
                    wasTranslated: false,
                    isPreviewPlaceholder: false
                )
            }

        var merged = Self.sortedDisplayedMessages(messages + pendingMessages)

        if merged.isEmpty {
            let preview = thread.preview.trimmingCharacters(in: .whitespacesAndNewlines)
            if !preview.isEmpty {
                let previewDirection =
                    thread.lastDirection.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "outbound"
                    ? "outbound"
                    : "inbound"
                merged = [
                    DisplayedThreadMessage(
                        id: "preview-\(threadID)",
                        direction: previewDirection,
                        fromNumber: nil,
                        toNumber: nil,
                        content: preview,
                        originalContent: nil,
                        sourceLanguage: nil,
                        targetLanguage: nil,
                        translationStatus: nil,
                        status: thread.lastStatus,
                        sentAt: thread.lastMessageAt ?? Self.timestamp(),
                        deliveryState: .sent,
                        deliveryReceipt: Self.deliveryReceipt(
                            forStatus: thread.lastStatus,
                            deliveryState: .sent,
                            direction: previewDirection
                        ),
                        failureReason: nil,
                        wasTranslated: false,
                        isPreviewPlaceholder: true
                    ),
                ]
            }
        }
        let preferredFromNumber = detail?.contact.preferredFromNumber ?? thread.preferredFromNumber

        return ThreadViewState(
            messages: merged,
            isLoading: loadingThreadIDs.contains(threadID),
            errorMessage: threadErrors[threadID],
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
#if DEBUG
            let effectiveThreads = threads.isEmpty ? self.threads : threads
#else
            let effectiveThreads = threads
#endif
            var merged = Dictionary(uniqueKeysWithValues: effectiveThreads.map { ($0.id, $0) })
            for existing in self.threads where pendingMessagesByThread[existing.id]?.isEmpty == false {
                merged[existing.id] = merged[existing.id] ?? existing
            }

            let presented = merged.values.map { applyLocalPresentation(to: $0) }
            self.threads = Self.sortedThreads(presented)
            inboxError = nil
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
        let threadID = thread.id
        if markRead {
            markReadLocally(contactId: thread.contactId)
            if (thread.unreadCount ?? 0) > 0 {
                Task {
                    await syncThreadAction(contactIds: [thread.contactId], action: "mark_read")
                }
            }
        }

        if threadDetails[threadID] != nil || loadingThreadIDs.contains(threadID) {
            return
        }

        await refreshThread(
            threadID: threadID,
            contactId: thread.contactId,
            fromNumber: thread.preferredFromNumber,
            forceRefresh: false
        )
    }

    func prefetchThreadIfNeeded(_ thread: MobileThreadSummary) async {
        let threadID = thread.id
        guard threadDetails[threadID] == nil,
              !loadingThreadIDs.contains(threadID),
              pendingMessagesByThread[threadID] == nil else {
            return
        }

        await refreshThread(
            threadID: threadID,
            contactId: thread.contactId,
            fromNumber: thread.preferredFromNumber,
            forceRefresh: false
        )
    }

    func prefetchThreadsIfNeeded(_ threads: [MobileThreadSummary], limit: Int = 8) async {
        guard limit > 0 else { return }

        for thread in threads.prefix(limit) {
            await prefetchThreadIfNeeded(thread)
        }
    }

    func refreshThread(
        contactId: String,
        fromNumber: String? = nil,
        forceRefresh: Bool = false
    ) async {
        guard let resolvedThreadID = threadStorageKey(
            threadID: nil,
            contactId: contactId,
            fromNumber: fromNumber
        ) else {
            return
        }
        await refreshThread(
            threadID: resolvedThreadID,
            contactId: contactId,
            fromNumber: fromNumber,
            forceRefresh: forceRefresh
        )
    }

    private func refreshThread(
        threadID: String,
        contactId: String,
        fromNumber: String?,
        forceRefresh: Bool
    ) async {
        if Self.usesLocalDebugBootstrap {
            threadErrors.removeValue(forKey: threadID)
            return
        }

        if loadingThreadIDs.contains(threadID) {
            return
        }

        loadingThreadIDs.insert(threadID)
        defer { loadingThreadIDs.remove(threadID) }

        do {
            let detail = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.threadDetail(
                    token: token,
                    contactId: contactId,
                    fromNumber: fromNumber,
                    forceRefresh: forceRefresh
                )
            }
            threadDetails[threadID] = detail
            persistThreadDetails()
            pruneConfirmedPendingMessages(for: threadID, serverMessages: detail.messages)
            threadErrors.removeValue(forKey: threadID)
            reconcileThreadSummary(
                from: detail,
                threadID: threadID,
                contactId: contactId,
                preferredFromNumber: fromNumber
            )
        } catch {
            threadErrors[threadID] = error.localizedDescription
        }
    }

    func sendMessage(
        in thread: MobileThreadSummary,
        fromNumber: String,
        message: String
    ) async {
        await sendMessage(
            threadID: thread.id,
            contactId: thread.contactId,
            phoneNumber: thread.contactPhone,
            contactName: thread.contactName,
            fromNumber: fromNumber,
            message: message
        )
    }

    func sendMessage(
        to phoneNumber: String?,
        contactName: String?,
        contactId: String?,
        fromNumber: String,
        message: String
    ) async {
        let normalizedPhone = Self.normalizedPhone(phoneNumber)
            ?? {
                guard let trimmed = phoneNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !trimmed.isEmpty else {
                    return nil
                }
                return trimmed
            }()
        let existing = contactId.flatMap { thread(for: $0) }
            ?? normalizedPhone.flatMap { existingThread(for: $0) }
        let fallbackThreadSeed = normalizedPhone
            ?? {
                guard let trimmed = contactId?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !trimmed.isEmpty else {
                    return nil
                }
                return trimmed
            }()
            ?? "unknown"
        let threadID = existing?.id
            ?? threadStorageKey(threadID: nil, contactId: contactId, fromNumber: fromNumber)
            ?? "draft:\(fallbackThreadSeed)"
        let resolvedName = existing?.contactName ?? contactName ?? normalizedPhone ?? "Conversation"

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
        let resolvedContactId = contactIdFromThreadID(record.threadID) ?? record.phoneNumber
        await sendMessage(
            threadID: contactId,
            contactId: record.threadID.hasPrefix("draft:") ? nil : resolvedContactId,
            phoneNumber: record.phoneNumber,
            contactName: record.contactName,
            fromNumber: record.fromNumber,
            message: record.content
        )
    }

    func clearTranslationDecisionPrompt() {
        translationDecisionPrompt = nil
    }

    func resolveTranslationDecision(promptID: String, action: String) async {
        guard let prompt = translationDecisionPrompt, prompt.id == promptID else { return }
        guard let record = pendingMessagesByThread[prompt.threadID]?.first(where: { $0.id == prompt.pendingMessageID }) else {
            translationDecisionPrompt = nil
            return
        }

        let normalizedAction = action.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedAction == "retry_translation" || normalizedAction == "send_original" else { return }

        translationDecisionPrompt = nil
        updatePendingMessage(
            id: record.id,
            threadID: record.threadID,
            deliveryState: .pending,
            failureReason: nil,
            serverMessageID: record.serverMessageID
        )

        do {
            let resolvedContactIdForRequest =
                record.threadID.hasPrefix("draft:")
                ? nil
                : (contactIdFromThreadID(record.threadID) ?? record.threadID)
            let response = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.sendMessage(
                    token: token,
                    contactId: resolvedContactIdForRequest,
                    toNumber: record.threadID.hasPrefix("draft:") ? record.phoneNumber : nil,
                    fromNumber: record.fromNumber,
                    message: record.content,
                    translationFailureAction: normalizedAction,
                    translationDecisionToken: prompt.decisionToken
                )
            }

            let resolvedContactId = response.contactId ?? resolvedContactIdForRequest ?? record.threadID
            let resolvedThreadID = threadStorageKey(
                threadID: record.threadID,
                contactId: resolvedContactId,
                fromNumber: record.fromNumber
            ) ?? record.threadID
            if resolvedThreadID != record.threadID {
                migrateThread(
                    from: record.threadID,
                    to: resolvedThreadID,
                    phoneNumber: record.phoneNumber,
                    contactName: record.contactName
                )
            }

            updatePendingMessage(
                id: record.id,
                threadID: resolvedThreadID,
                deliveryState: .sent,
                failureReason: nil,
                serverMessageID: response.messageId,
                translationDecisionToken: nil,
                translationSourceLanguage: nil,
                translationTargetLanguage: nil
            )
            threadErrors.removeValue(forKey: resolvedThreadID)
            Task {
                await refreshThread(
                    threadID: resolvedThreadID,
                    contactId: resolvedContactId,
                    fromNumber: record.fromNumber,
                    forceRefresh: true
                )
            }
        } catch {
            if case let RotaryAPIError.requestFailed(_, message, code, details) = error,
               code == "translation_decision_required",
               let decisionToken = details?["decisionToken"] {
                updatePendingMessage(
                    id: record.id,
                    threadID: record.threadID,
                    deliveryState: .failed,
                    failureReason: "Translation unavailable. Choose retry or send original.",
                    serverMessageID: nil,
                    translationDecisionToken: decisionToken,
                    translationSourceLanguage: details?["sourceLanguage"],
                    translationTargetLanguage: details?["targetLanguage"]
                )
                translationDecisionPrompt = TranslationDecisionPrompt(
                    id: "translation:\(record.id)",
                    threadID: record.threadID,
                    pendingMessageID: record.id,
                    decisionToken: decisionToken,
                    message: message,
                    sourceLanguage: details?["sourceLanguage"],
                    targetLanguage: details?["targetLanguage"]
                )
                return
            }

            updatePendingMessage(
                id: record.id,
                threadID: record.threadID,
                deliveryState: .failed,
                failureReason: error.localizedDescription,
                serverMessageID: nil
            )
            threadErrors[record.threadID] = error.localizedDescription
        }
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
        let tempID = "temp-contact:\(UUID().uuidString)"
        let result = try await mutationDispatcher.createContact(
            tempID: tempID,
            name: name,
            phoneNumber: phoneNumber,
            email: email,
            company: company,
            fullAddress: fullAddress,
            avatarURL: avatarURL
        )

        switch result {
        case .executed(let payload):
            return payload.contact
        case .queued:
            return MobileCreatedContact(
                id: tempID,
                name: name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? name! : phoneNumber,
                phone: phoneNumber,
                email: email,
                avatarUrl: avatarURL,
                company: company,
                fullAddress: fullAddress
            )
        }
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
        let result = try await mutationDispatcher.updateContact(
            contactId: contactId,
            name: name,
            phoneNumber: phoneNumber,
            email: email,
            company: company,
            fullAddress: fullAddress,
            avatarURL: avatarURL
        )

        switch result {
        case .executed(let payload):
            return payload.contact
        case .queued:
            return MobileCreatedContact(
                id: contactId,
                name: name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? name! : (phoneNumber ?? "Pending contact"),
                phone: phoneNumber,
                email: email,
                avatarUrl: avatarURL,
                company: company,
                fullAddress: fullAddress
            )
        }
    }

    func updateThreadLanguage(contactId: String, contactLanguage: String?) async throws {
        let payload = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
            try await api.updateThreadLanguage(
                token: token,
                contactId: contactId,
                contactLanguage: contactLanguage
            )
        }

        for threadID in threadDetails.keys {
            guard let threadContactID = contactIdFromThreadID(threadID),
                  threadContactID == contactId,
                  var detail = threadDetails[threadID] else {
                continue
            }
            let currentContact = detail.contact
            detail = MobileThreadDetail(
                contact: .init(
                    threadId: currentContact.threadId,
                    id: currentContact.id,
                    name: currentContact.name,
                    phone: currentContact.phone,
                    email: currentContact.email,
                    lastContactedAt: currentContact.lastContactedAt,
                    lastActivitySummary: currentContact.lastActivitySummary,
                    avatarUrl: currentContact.avatarUrl,
                    company: currentContact.company,
                    fullAddress: currentContact.fullAddress,
                    website: currentContact.website,
                    cityName: currentContact.cityName,
                    latitude: currentContact.latitude,
                    longitude: currentContact.longitude,
                    socialProfiles: currentContact.socialProfiles,
                    preferredFromNumber: currentContact.preferredFromNumber,
                    contactLanguage: payload.contactLanguage,
                    userLanguage: payload.userLanguage,
                    translationMode: payload.translationMode,
                    translationEnabled: payload.translationEnabled
                ),
                participants: detail.participants,
                messages: detail.messages
            )
            threadDetails[threadID] = detail
        }
        persistThreadDetails()

        threads = threads.map { summary in
            guard summary.contactId == contactId else { return summary }
            var updated = summary
            updated.contactLanguage = payload.contactLanguage
            updated.userLanguage = payload.userLanguage
            updated.translationMode = payload.translationMode
            updated.translationEnabled = payload.translationEnabled
            return updated
        }
    }

    func exportThreadsToAgent(agentId: String, threadIDs: [String]) async throws {
        let selectedIDs = Set(threadIDs)
        let selectedThreads = threads.filter { selectedIDs.contains($0.id) }
        guard !selectedThreads.isEmpty else { return }

        let digestEntries = selectedThreads.compactMap { thread -> String? in
            var lines: [String] = []
            let contactName = thread.contactName.trimmingCharacters(in: .whitespacesAndNewlines)
            lines.append("Contact: \(contactName.isEmpty ? "Unknown" : contactName)")
            if let contactPhone = thread.contactPhone?.trimmingCharacters(in: .whitespacesAndNewlines),
               !contactPhone.isEmpty {
                lines.append("Phone: \(contactPhone)")
            }
            let fromNumber = thread.preferredFromNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            if !fromNumber.isEmpty {
                lines.append("From Line: \(fromNumber)")
            }

            let detailMessages = threadDetails[thread.id]?.messages.suffix(8) ?? []
            if !detailMessages.isEmpty {
                lines.append("Recent Messages:")
                for message in detailMessages {
                    let direction = message.direction == "outbound" ? "User" : "Contact"
                    let rendered = message.renderedContent?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let displayed = message.displayContent?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let contentCandidate = rendered?.isEmpty == false
                        ? rendered
                        : (displayed?.isEmpty == false ? displayed : message.content.trimmingCharacters(in: .whitespacesAndNewlines))
                    guard let content = contentCandidate, !content.isEmpty else {
                        continue
                    }
                    lines.append("- \(direction): \(content)")
                }
            } else if !thread.preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("Latest Preview: \(thread.preview)")
            }

            return lines.isEmpty ? nil : lines.joined(separator: "\n")
        }

        guard !digestEntries.isEmpty else { return }
        let payload = """
        Please ingest these selected message threads as context for follow-up planning and execution.

        \(digestEntries.joined(separator: "\n\n---\n\n"))
        """

        _ = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
            try await api.sendAgentConversationMessage(
                token: token,
                agentId: agentId,
                message: payload,
                attachmentIds: [],
                thinkingMode: "balanced"
            )
        }
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
            serverMessageID: nil,
            translationDecisionToken: nil,
            translationSourceLanguage: nil,
            translationTargetLanguage: nil,
            queuedOperationID: nil
        )

        addPendingMessage(pending)
        upsertThreadSummary(
            threadID: threadID,
            contactId: contactIdFromThreadID(threadID) ?? contactId ?? threadID,
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
            let dispatchResult = try await mutationDispatcher.sendMessage(
                contactId: contactId,
                toNumber: contactId == nil ? phoneNumber : nil,
                fromNumber: fromNumber,
                message: trimmedMessage
            )

            switch dispatchResult {
            case .executed(let response):
                let resolvedContactId = response.contactId
                    ?? contactId
                    ?? existingThread(for: phoneNumber ?? "")?.contactId
                    ?? contactIdFromThreadID(threadID)
                    ?? threadID
                let resolvedThreadID = threadStorageKey(
                    threadID: threadID,
                    contactId: resolvedContactId,
                    fromNumber: fromNumber
                ) ?? threadID

                if resolvedThreadID != threadID {
                    migrateThread(
                        from: threadID,
                        to: resolvedThreadID,
                        phoneNumber: phoneNumber,
                        contactName: contactName
                    )
                }

                updatePendingMessage(
                    id: pending.id,
                    threadID: resolvedThreadID,
                    deliveryState: .sent,
                    failureReason: nil,
                    serverMessageID: response.messageId,
                    translationDecisionToken: nil,
                    translationSourceLanguage: nil,
                    translationTargetLanguage: nil,
                    queuedOperationID: nil
                )

                threadErrors.removeValue(forKey: resolvedThreadID)

                Task {
                    await refreshThread(
                        threadID: resolvedThreadID,
                        contactId: resolvedContactId,
                        fromNumber: fromNumber,
                        forceRefresh: true
                    )
                }

                if response.contactId == nil, resolvedThreadID.hasPrefix("draft:") {
                    Task {
                        await refreshInbox(forceRefresh: true)
                    }
                }
            case .queued(let operationID):
                updatePendingMessage(
                    id: pending.id,
                    threadID: threadID,
                    deliveryState: .pending,
                    failureReason: nil,
                    serverMessageID: nil,
                    queuedOperationID: operationID
                )
                threadErrors.removeValue(forKey: threadID)
            }
        } catch {
            if case let RotaryAPIError.requestFailed(_, message, code, details) = error,
               code == "translation_decision_required",
               let decisionToken = details?["decisionToken"] {
                updatePendingMessage(
                    id: pending.id,
                    threadID: threadID,
                    deliveryState: .failed,
                    failureReason: "Translation unavailable. Choose retry or send original.",
                    serverMessageID: nil,
                    translationDecisionToken: decisionToken,
                    translationSourceLanguage: details?["sourceLanguage"],
                    translationTargetLanguage: details?["targetLanguage"]
                )
                translationDecisionPrompt = TranslationDecisionPrompt(
                    id: "translation:\(pending.id)",
                    threadID: threadID,
                    pendingMessageID: pending.id,
                    decisionToken: decisionToken,
                    message: message,
                    sourceLanguage: details?["sourceLanguage"],
                    targetLanguage: details?["targetLanguage"]
                )
                threadErrors.removeValue(forKey: threadID)
                return
            }

            updatePendingMessage(
                id: pending.id,
                threadID: threadID,
                deliveryState: .failed,
                failureReason: error.localizedDescription,
                serverMessageID: nil,
                queuedOperationID: nil
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
            let result = try await mutationDispatcher.updateThreads(contactIds: contactIds, action: action)
            if case .queued = result {
                inboxError = "Thread change queued offline."
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
        persistPendingMessages()
    }

    private func removePendingMessage(id: String, threadID: String) {
        pendingMessagesByThread[threadID]?.removeAll { $0.id == id }
        if pendingMessagesByThread[threadID]?.isEmpty == true {
            pendingMessagesByThread.removeValue(forKey: threadID)
        }
        persistPendingMessages()
    }

    private func updatePendingMessage(
        id: String,
        threadID: String,
        deliveryState: MessageDeliveryState,
        failureReason: String?,
        serverMessageID: String?,
        translationDecisionToken: String? = nil,
        translationSourceLanguage: String? = nil,
        translationTargetLanguage: String? = nil,
        queuedOperationID: String? = nil
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
            if translationDecisionToken != nil || deliveryState == .sent {
                record.translationDecisionToken = translationDecisionToken
            }
            if translationSourceLanguage != nil || deliveryState == .sent {
                record.translationSourceLanguage = translationSourceLanguage
            }
            if translationTargetLanguage != nil || deliveryState == .sent {
                record.translationTargetLanguage = translationTargetLanguage
            }
            record.queuedOperationID = queuedOperationID

            pendingMessagesByThread[key]!.remove(at: index)
            pendingMessagesByThread[threadID, default: []].append(record)
            sortPendingMessages(for: threadID)

            if pendingMessagesByThread[key]?.isEmpty == true {
                pendingMessagesByThread.removeValue(forKey: key)
            }
            persistPendingMessages()
            break
        }
    }

    private func migrateThread(from oldID: String, to newID: String, phoneNumber: String?, contactName: String) {
        if let detail = threadDetails.removeValue(forKey: oldID) {
            threadDetails[newID] = detail
            persistThreadDetails()
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
            persistPendingMessages()
        }

        threads = threads.map { thread in
            guard thread.id == oldID else { return thread }
            return MobileThreadSummary(
                threadId: newID,
                contactId: contactIdFromThreadID(newID) ?? thread.contactId,
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
                isSpam: thread.isSpam,
                contactLanguage: thread.contactLanguage,
                userLanguage: thread.userLanguage,
                translationMode: thread.translationMode,
                translationEnabled: thread.translationEnabled
            )
        }

        if !threads.contains(where: { $0.id == newID }) {
            upsertThreadSummary(
                threadID: newID,
                contactId: contactIdFromThreadID(newID) ?? newID,
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

    private func reconcileThreadSummary(
        from detail: MobileThreadDetail,
        threadID: String,
        contactId: String,
        preferredFromNumber: String?
    ) {
        guard let lastMessage = detail.messages.last else { return }

        upsertThreadSummary(
            threadID: threadID,
            contactId: contactId,
            contactName: detail.contact.name,
            contactPhone: detail.contact.phone,
            preview: (lastMessage.displayContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? (lastMessage.displayContent ?? lastMessage.content)
                : lastMessage.content,
            lastDirection: lastMessage.direction,
            lastStatus: lastMessage.status,
            lastMessageAt: lastMessage.sentAt,
            preferredFromNumber: preferredFromNumber ?? detail.contact.preferredFromNumber,
            unreadCount: thread(threadID: threadID)?.unreadCount ?? 0,
            isDeleted: thread(threadID: threadID)?.isDeleted ?? false,
            isSpam: thread(threadID: threadID)?.isSpam ?? false
        )
    }

    private func upsertThreadSummary(
        threadID: String,
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
        let existing = thread(threadID: threadID) ?? thread(for: contactId)
        let summary = MobileThreadSummary(
            threadId: threadID,
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
            isSpam: isSpam ?? existing?.isSpam,
            contactLanguage: existing?.contactLanguage,
            userLanguage: existing?.userLanguage,
            translationMode: existing?.translationMode,
            translationEnabled: existing?.translationEnabled
        )

        threads.removeAll { $0.id == threadID }
        threads.append(summary)
        threads = Self.sortedThreads(threads.map { applyLocalPresentation(to: $0) })
        filterCounts = Self.recomputeFilterCounts(from: threads, fallbackUnread: self.unreadCount())
    }

    private func applyLocalPresentation(to summary: MobileThreadSummary) -> MobileThreadSummary {
        guard let pending = pendingMessagesByThread[summary.id]?.sorted(by: { $0.createdAt < $1.createdAt }).last else {
            return summary
        }

        return MobileThreadSummary(
            threadId: summary.threadId,
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
            isSpam: summary.isSpam,
            contactLanguage: summary.contactLanguage,
            userLanguage: summary.userLanguage,
            translationMode: summary.translationMode,
            translationEnabled: summary.translationEnabled
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

    private func pruneConfirmedPendingMessages(
        for threadID: String,
        serverMessages: [MobileThreadMessage]
    ) {
        guard var pending = pendingMessagesByThread[threadID], !pending.isEmpty else { return }

        let originalCount = pending.count
        pending.removeAll { record in
            serverConfirms(record, serverMessages: serverMessages)
        }

        if pending.isEmpty {
            pendingMessagesByThread.removeValue(forKey: threadID)
        } else {
            pendingMessagesByThread[threadID] = pending
        }

        if originalCount != pending.count {
            persistPendingMessages()
        }
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
                    isSpam: thread.isSpam,
                    contactLanguage: thread.contactLanguage,
                    userLanguage: thread.userLanguage,
                    translationMode: thread.translationMode,
                    translationEnabled: thread.translationEnabled
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
                    isSpam: thread.isSpam,
                    contactLanguage: thread.contactLanguage,
                    userLanguage: thread.userLanguage,
                    translationMode: thread.translationMode,
                    translationEnabled: thread.translationEnabled
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
                    isSpam: false,
                    contactLanguage: thread.contactLanguage,
                    userLanguage: thread.userLanguage,
                    translationMode: thread.translationMode,
                    translationEnabled: thread.translationEnabled
                )
            case "leave_group":
                return MobileThreadSummary(
                    contactId: thread.contactId,
                    contactName: thread.contactName,
                    contactPhone: thread.contactPhone,
                    contactEmail: thread.contactEmail,
                    preview: "You left the group",
                    lastDirection: "outbound",
                    lastStatus: "left_group",
                    lastMessageAt: thread.lastMessageAt,
                    preferredFromNumber: thread.preferredFromNumber,
                    unreadCount: 0,
                    isDeleted: true,
                    isSpam: false,
                    contactLanguage: thread.contactLanguage,
                    userLanguage: thread.userLanguage,
                    translationMode: thread.translationMode,
                    translationEnabled: thread.translationEnabled
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
                    isSpam: false,
                    contactLanguage: thread.contactLanguage,
                    userLanguage: thread.userLanguage,
                    translationMode: thread.translationMode,
                    translationEnabled: thread.translationEnabled
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
                    isSpam: true,
                    contactLanguage: thread.contactLanguage,
                    userLanguage: thread.userLanguage,
                    translationMode: thread.translationMode,
                    translationEnabled: thread.translationEnabled
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
                    isSpam: false,
                    contactLanguage: thread.contactLanguage,
                    userLanguage: thread.userLanguage,
                    translationMode: thread.translationMode,
                    translationEnabled: thread.translationEnabled
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

    private func threadStorageKey(
        threadID: String?,
        contactId: String?,
        fromNumber: String?
    ) -> String? {
        if let threadID = threadID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !threadID.isEmpty {
            if threadID.hasPrefix("draft:") || threadID.contains("::") {
                return threadID
            }
        }

        guard let contactId = contactId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !contactId.isEmpty else {
            return threadID?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let normalizedFromNumber = fromNumber?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")

        if let normalizedFromNumber, !normalizedFromNumber.isEmpty {
            return "\(contactId)::\(normalizedFromNumber)"
        }
        return contactId
    }

    private func contactIdFromThreadID(_ threadID: String?) -> String? {
        guard let threadID = threadID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !threadID.isEmpty else {
            return nil
        }
        if threadID.hasPrefix("draft:") {
            return nil
        }
        if let separator = threadID.range(of: "::") {
            return String(threadID[..<separator.lowerBound])
        }
        return threadID
    }

    private static var pendingMessagesFileURL: URL {
        let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return (appSupportDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("rotary-pending-messages.json", conformingTo: .json)
    }

    private static var threadDetailsFileURL: URL {
        let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return (appSupportDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("rotary-thread-details.json", conformingTo: .json)
    }

    private static func loadPersistedPendingMessages() -> [String: [PendingMessageRecord]] {
        guard let data = try? Data(contentsOf: pendingMessagesFileURL) else {
            return [:]
        }
        guard let decoded = try? JSONDecoder().decode([String: [PendingMessageRecord]].self, from: data) else {
            try? FileManager.default.removeItem(at: pendingMessagesFileURL)
            return [:]
        }
        return decoded
    }

    private func persistPendingMessages() {
        let fileURL = Self.pendingMessagesFileURL
        let fileManager = FileManager.default

        if pendingMessagesByThread.isEmpty {
            try? fileManager.removeItem(at: fileURL)
            return
        }

        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(pendingMessagesByThread)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Failed to persist pending thread messages: \(error)")
        }
    }

    private static func loadPersistedThreadDetails() -> [String: MobileThreadDetail] {
        guard let data = try? Data(contentsOf: threadDetailsFileURL) else {
            return [:]
        }
        guard let decoded = try? JSONDecoder().decode([String: MobileThreadDetail].self, from: data) else {
            try? FileManager.default.removeItem(at: threadDetailsFileURL)
            return [:]
        }
        return decoded
    }

    private func persistThreadDetails() {
        let fileURL = Self.threadDetailsFileURL
        let fileManager = FileManager.default

        if threadDetails.isEmpty {
            try? fileManager.removeItem(at: fileURL)
            return
        }

        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(threadDetails)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Failed to persist message thread details: \(error)")
        }
    }

    private static func deliveryReceipt(
        forStatus status: String,
        deliveryState: MessageDeliveryState,
        direction: String
    ) -> ThreadDeliveryReceipt? {
        guard direction.lowercased() == "outbound" else { return nil }

        switch deliveryState {
        case .failed:
            return .undelivered
        case .pending:
            return .sent
        case .sent:
            break
        }

        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("read") {
            return .read
        }
        if normalized.contains("deliver") {
            return .delivered
        }
        if normalized.contains("undeliver") || normalized.contains("failed") {
            return .undelivered
        }
        return .sent
    }

    private static func messageWasTranslated(
        originalContent: String?,
        renderedContent: String,
        translationStatus: String?
    ) -> Bool {
        if let originalContent = originalContent?.trimmingCharacters(in: .whitespacesAndNewlines),
           !originalContent.isEmpty,
           originalContent != renderedContent.trimmingCharacters(in: .whitespacesAndNewlines) {
            return true
        }

        guard let translationStatus = translationStatus?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !translationStatus.isEmpty else {
            return false
        }
        return translationStatus.contains("translated")
            || translationStatus.contains("complete")
            || translationStatus.contains("success")
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

    private static func timestamp(offsetBy interval: TimeInterval = 0) -> String {
        ISO8601DateFormatter().string(from: Date().addingTimeInterval(interval))
    }

    private static func debugSeedThreads(from bootstrap: MobileBootstrapReadyState) -> [MobileThreadSummary] {
#if DEBUG
        [debugSeedConversation(from: bootstrap).thread]
#else
        []
#endif
    }

    private static func debugSeedThreadDetails(from bootstrap: MobileBootstrapReadyState) -> [String: MobileThreadDetail] {
#if DEBUG
        let seed = debugSeedConversation(from: bootstrap)
        return [seed.thread.id: seed.detail]
#else
        return [:]
#endif
    }

#if DEBUG
    private static func debugSeedConversation(from bootstrap: MobileBootstrapReadyState) -> DebugSeedConversation {
        let fromNumber = normalizedPhone(
            bootstrap.ownerLine?.phoneNumber
                ?? bootstrap.capabilities.defaultMainLine
        ) ?? bootstrap.capabilities.defaultMainLine
        let contactPhone = normalizedPhone(bootstrap.ownerCellNumber)
            ?? normalizedPhone(bootstrap.transferDestinations.first?.phoneNumber)
            ?? fromNumber
        let threadID = "debug-message-jacob-lopez"
        let contactID = "debug-contact-jacob-lopez"
        let now = timestamp()
        let earlier = timestamp(offsetBy: -6 * 60)

        let thread = MobileThreadSummary(
            threadId: threadID,
            contactId: contactID,
            contactName: "Jacob Lopez",
            contactPhone: contactPhone,
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

        let detail = MobileThreadDetail(
            contact: MobileThreadDetail.Contact(
                threadId: threadID,
                id: contactID,
                name: "Jacob Lopez",
                phone: contactPhone,
                email: nil,
                lastContactedAt: now,
                lastActivitySummary: thread.preview,
                avatarUrl: nil,
                company: nil,
                fullAddress: nil,
                website: nil,
                cityName: nil,
                latitude: nil,
                longitude: nil,
                socialProfiles: nil,
                preferredFromNumber: fromNumber,
                contactLanguage: nil,
                userLanguage: nil,
                translationMode: nil,
                translationEnabled: nil
            ),
            participants: nil,
            messages: [
                MobileThreadMessage(
                    id: "debug-message-jacob-lopez-1",
                    direction: "inbound",
                    fromNumber: contactPhone,
                    toNumber: fromNumber,
                    content: "Can you confirm the second live update?",
                    renderedContent: nil,
                    renderStatus: nil,
                    displayContent: nil,
                    originalContent: nil,
                    translatedContent: nil,
                    sourceLanguage: nil,
                    targetLanguage: nil,
                    translationStatus: nil,
                    translationProvider: nil,
                    status: "delivered",
                    sentAt: earlier,
                    rawPayload: [:]
                ),
                MobileThreadMessage(
                    id: "debug-message-jacob-lopez-2",
                    direction: "outbound",
                    fromNumber: fromNumber,
                    toNumber: contactPhone,
                    content: "Second live confirmation from crm message_local",
                    renderedContent: nil,
                    renderStatus: nil,
                    displayContent: nil,
                    originalContent: nil,
                    translatedContent: nil,
                    sourceLanguage: nil,
                    targetLanguage: nil,
                    translationStatus: nil,
                    translationProvider: nil,
                    status: "sent",
                    sentAt: now,
                    rawPayload: [:]
                )
            ]
        )

        return DebugSeedConversation(thread: thread, detail: detail)
    }
#endif

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
