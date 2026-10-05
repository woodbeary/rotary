import Foundation
import Observation
import UIKit

@MainActor
protocol RotaryMutationCommanding: AnyObject {
    var pendingCount: Int { get }
    var failedCount: Int { get }
    var isSyncing: Bool { get }
    var lastSyncMessage: String? { get }
    var lastSuccessfulSyncAt: Date? { get }

    func sendMessage(
        contactId: String?,
        toNumber: String?,
        fromNumber: String,
        message: String
    ) async throws -> MutationDispatchResult<MobileSendMessageResponse>

    func updateThreads(contactIds: [String], action: String) async throws -> MutationDispatchResult<MobileThreadBulkUpdateResponse>

    func createContact(
        tempID: String,
        name: String?,
        phoneNumber: String,
        email: String?,
        company: String?,
        fullAddress: String?,
        avatarURL: String?
    ) async throws -> MutationDispatchResult<MobileCreatedContactResponse>

    func updateContact(
        contactId: String,
        name: String?,
        phoneNumber: String?,
        email: String?,
        company: String?,
        fullAddress: String?,
        avatarURL: String?
    ) async throws -> MutationDispatchResult<MobileCreatedContactResponse>

    func createFolder(
        tempID: String,
        name: String,
        description: String?,
        color: String?
    ) async throws -> MutationDispatchResult<MobileCreateFolderResponse>

    func updateFolder(
        folderId: String,
        name: String,
        description: String?,
        color: String?
    ) async throws -> MutationDispatchResult<MobileCreateFolderResponse>

    func createWorkspace(name: String) async throws -> MutationDispatchResult<EmptyPayload>

    func createAgent(
        tempID: String,
        name: String,
        purpose: String,
        voiceName: String,
        voiceProfileId: String?,
        thinkingMode: String,
        folderId: String?
    ) async throws -> MutationDispatchResult<MobileAgent>

    func provisionOwnerLine(tempID: String, phoneNumber: String) async throws -> MutationDispatchResult<MobileLine>

    func provisionAgentLine(agentId: String, folderId: String?) async throws -> MutationDispatchResult<MobileLine>

    func updateCallScreening(enabled: Bool) async throws -> MutationDispatchResult<MobileCallScreeningSettings>

    func registerDevice(
        pushToken: String?,
        voipPushToken: String?,
        clientReady: Bool
    ) async throws -> MutationDispatchResult<DeviceRegistrationResponse>

    func sendAgentConversationMessage(
        agentId: String,
        message: String?,
        attachmentIds: [String],
        thinkingMode: String
    ) async throws -> MutationDispatchResult<MobileAgentConversationMessageResponse>

    func uploadAgentAttachment(
        agentId: String,
        tempID: String,
        payload: RotaryUploadAttachmentPayload
    ) async throws -> MutationDispatchResult<MobileAgentAttachmentUploadResponse>

    func flushPendingMutations() async
    func retryFailedMutations() async
    func failedRecords() async -> [OfflineMutationRecord]
}

@MainActor
@Observable
final class RotaryMutationDispatcher: RotaryMutationCommanding {
    static let shared = RotaryMutationDispatcher(api: RotaryAPIClient())

    private let api: RotaryAPIClient
    private let queue: OfflineMutationQueue
    private let connectivityMonitor: ConnectivityMonitor

    private var tokenProvider: RotaryTokenProvider?
    private var connectivityObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    private(set) var pendingCount = 0
    private(set) var failedCount = 0
    private(set) var isSyncing = false
    private(set) var lastSyncMessage: String?
    private(set) var lastSuccessfulSyncAt: Date?
    private(set) var latestFailureReason: String?

    init(
        api: RotaryAPIClient,
        queue: OfflineMutationQueue = OfflineMutationQueue(),
        connectivityMonitor: ConnectivityMonitor = .shared
    ) {
        self.api = api
        self.queue = queue
        self.connectivityMonitor = connectivityMonitor

        connectivityObserver = NotificationCenter.default.addObserver(
            forName: .rotaryConnectivityChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleConnectivityChange()
            }
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.flushPendingMutations()
            }
        }

        Task { @MainActor [weak self] in
            await self?.refreshSnapshot()
        }
    }

    func configureTokenProvider(_ tokenProvider: RotaryTokenProvider?) {
        self.tokenProvider = tokenProvider
    }

    func sendMessage(
        contactId: String?,
        toNumber: String?,
        fromNumber: String,
        message: String
    ) async throws -> MutationDispatchResult<MobileSendMessageResponse> {
        let payload = OfflineMutationPayload.sendMessage(
            SendMessageMutationPayload(
                contactId: contactId,
                toNumber: toNumber,
                fromNumber: fromNumber,
                message: message
            )
        )

        return try await executeOrQueue(payload: payload) { token in
            let response = try await self.api.sendMessage(
                token: token,
                contactId: contactId,
                toNumber: toNumber,
                fromNumber: fromNumber,
                message: message
            )
            return (response, nil)
        }
    }

    func updateThreads(contactIds: [String], action: String) async throws -> MutationDispatchResult<MobileThreadBulkUpdateResponse> {
        let payload = OfflineMutationPayload.updateThreads(
            UpdateThreadsMutationPayload(contactIds: contactIds, action: action)
        )

        return try await executeOrQueue(payload: payload) { token in
            let response = try await self.api.updateThreads(token: token, contactIds: contactIds, action: action)
            return (response, nil)
        }
    }

    func createContact(
        tempID: String,
        name: String?,
        phoneNumber: String,
        email: String?,
        company: String?,
        fullAddress: String?,
        avatarURL: String?
    ) async throws -> MutationDispatchResult<MobileCreatedContactResponse> {
        let payload = OfflineMutationPayload.createContact(
            CreateContactMutationPayload(
                tempID: tempID,
                name: name,
                phoneNumber: phoneNumber,
                email: email,
                company: company,
                fullAddress: fullAddress,
                avatarURL: avatarURL
            )
        )

        return try await executeOrQueue(payload: payload) { token in
            let response = try await self.api.createContact(
                token: token,
                name: name,
                phoneNumber: phoneNumber,
                email: email,
                company: company,
                fullAddress: fullAddress,
                avatarURL: avatarURL
            )
            return (response, (tempID, response.contact.id))
        }
    }

    func updateContact(
        contactId: String,
        name: String?,
        phoneNumber: String?,
        email: String?,
        company: String?,
        fullAddress: String?,
        avatarURL: String?
    ) async throws -> MutationDispatchResult<MobileCreatedContactResponse> {
        let payload = OfflineMutationPayload.updateContact(
            UpdateContactMutationPayload(
                contactId: contactId,
                name: name,
                phoneNumber: phoneNumber,
                email: email,
                company: company,
                fullAddress: fullAddress,
                avatarURL: avatarURL
            )
        )

        return try await executeOrQueue(payload: payload) { token in
            let response = try await self.api.updateContact(
                token: token,
                contactId: contactId,
                name: name,
                phoneNumber: phoneNumber,
                email: email,
                company: company,
                fullAddress: fullAddress,
                avatarURL: avatarURL
            )
            return (response, nil)
        }
    }

    func createFolder(
        tempID: String,
        name: String,
        description: String?,
        color: String?
    ) async throws -> MutationDispatchResult<MobileCreateFolderResponse> {
        let payload = OfflineMutationPayload.createFolder(
            CreateFolderMutationPayload(
                tempID: tempID,
                name: name,
                description: description,
                color: color
            )
        )

        return try await executeOrQueue(payload: payload) { token in
            let response = try await self.api.createFolderDetailed(token: token, name: name, description: description, color: color)
            if let folderID = response.folder?.id {
                return (response, (tempID, folderID))
            }
            return (response, nil)
        }
    }

    func updateFolder(
        folderId: String,
        name: String,
        description: String?,
        color: String?
    ) async throws -> MutationDispatchResult<MobileCreateFolderResponse> {
        let payload = OfflineMutationPayload.updateFolder(
            UpdateFolderMutationPayload(
                folderId: folderId,
                name: name,
                description: description,
                color: color
            )
        )

        return try await executeOrQueue(payload: payload) { token in
            let response = try await self.api.updateFolderDetailed(
                token: token,
                folderId: folderId,
                name: name,
                description: description,
                color: color
            )
            return (response, nil)
        }
    }

    func createWorkspace(name: String) async throws -> MutationDispatchResult<EmptyPayload> {
        let payload = OfflineMutationPayload.createWorkspace(
            CreateWorkspaceMutationPayload(businessName: name)
        )

        return try await executeOrQueue(payload: payload) { token in
            try await self.api.createWorkspace(token: token, businessName: name)
            return (EmptyPayload(), nil)
        }
    }

    func createAgent(
        tempID: String,
        name: String,
        purpose: String,
        voiceName: String,
        voiceProfileId: String?,
        thinkingMode: String,
        folderId: String?
    ) async throws -> MutationDispatchResult<MobileAgent> {
        let payload = OfflineMutationPayload.createAgent(
            CreateAgentMutationPayload(
                tempID: tempID,
                name: name,
                purpose: purpose,
                voiceName: voiceName,
                voiceProfileId: voiceProfileId,
                thinkingMode: thinkingMode,
                folderId: folderId
            )
        )

        return try await executeOrQueue(payload: payload) { token in
            let agent = try await self.api.createAgent(
                token: token,
                name: name,
                purpose: purpose,
                voiceName: voiceName,
                voiceProfileId: voiceProfileId,
                thinkingMode: thinkingMode,
                folderId: folderId
            )
            return (agent, (tempID, agent.id))
        }
    }

    func provisionOwnerLine(tempID: String, phoneNumber: String) async throws -> MutationDispatchResult<MobileLine> {
        let payload = OfflineMutationPayload.provisionOwnerLine(
            ProvisionOwnerLineMutationPayload(tempID: tempID, phoneNumber: phoneNumber)
        )

        return try await executeOrQueue(payload: payload) { token in
            let line = try await self.api.provisionOwnerLine(token: token, phoneNumber: phoneNumber)
            return (line, (tempID, line.id))
        }
    }

    func provisionAgentLine(agentId: String, folderId: String?) async throws -> MutationDispatchResult<MobileLine> {
        let payload = OfflineMutationPayload.provisionAgentLine(
            ProvisionAgentLineMutationPayload(agentId: agentId, folderId: folderId)
        )

        return try await executeOrQueue(payload: payload) { token in
            let line = try await self.api.provisionAgentLine(token: token, agentId: agentId, folderId: folderId)
            return (line, nil)
        }
    }

    func updateCallScreening(enabled: Bool) async throws -> MutationDispatchResult<MobileCallScreeningSettings> {
        let payload = OfflineMutationPayload.updateCallScreening(
            UpdateCallScreeningMutationPayload(enabled: enabled)
        )

        return try await executeOrQueue(payload: payload) { token in
            let response = try await self.api.updateCallScreeningSettings(token: token, enabled: enabled)
            return (response, nil)
        }
    }

    func registerDevice(
        pushToken: String?,
        voipPushToken: String?,
        clientReady: Bool
    ) async throws -> MutationDispatchResult<DeviceRegistrationResponse> {
        let payload = OfflineMutationPayload.registerDevice(
            RegisterDeviceMutationPayload(
                pushToken: pushToken,
                voipPushToken: voipPushToken,
                clientReady: clientReady
            )
        )

        return try await executeOrQueue(payload: payload) { token in
            let response = try await self.api.registerDevice(
                token: token,
                pushToken: pushToken,
                voipPushToken: voipPushToken,
                clientReady: clientReady
            )
            return (response, nil)
        }
    }

    func sendAgentConversationMessage(
        agentId: String,
        message: String?,
        attachmentIds: [String],
        thinkingMode: String
    ) async throws -> MutationDispatchResult<MobileAgentConversationMessageResponse> {
        let payload = OfflineMutationPayload.sendAgentConversationMessage(
            SendAgentConversationMessageMutationPayload(
                agentId: agentId,
                message: message,
                attachmentIds: attachmentIds,
                thinkingMode: thinkingMode
            )
        )

        if attachmentIds.contains(where: isTemporaryReference) {
            return await queueNow(payload)
        }

        return try await executeOrQueue(payload: payload) { token in
            let response = try await self.api.sendAgentConversationMessage(
                token: token,
                agentId: agentId,
                message: message,
                attachmentIds: attachmentIds,
                thinkingMode: thinkingMode
            )
            return (response, nil)
        }
    }

    func uploadAgentAttachment(
        agentId: String,
        tempID: String,
        payload: RotaryUploadAttachmentPayload
    ) async throws -> MutationDispatchResult<MobileAgentAttachmentUploadResponse> {
        let mutationPayload = OfflineMutationPayload.uploadAgentAttachment(
            UploadAgentAttachmentMutationPayload(
                agentId: agentId,
                tempID: tempID,
                payload: RotaryUploadAttachmentPayloadEnvelope(payload: payload)
            )
        )

        return try await executeOrQueue(payload: mutationPayload) { token in
            let response = try await self.api.uploadAgentAttachment(token: token, agentId: agentId, payload: payload)
            return (response, (tempID, response.attachment.id))
        }
    }

    func retryFailedMutations() async {
        await queue.markFailedAsPending()
        await refreshSnapshot()
        await flushPendingMutations()
    }

    func failedRecords() async -> [OfflineMutationRecord] {
        await queue.failedRecords()
    }

    func flushPendingMutations() async {
        guard connectivityMonitor.isOnline else {
            await refreshSnapshot()
            return
        }

        guard !isSyncing else { return }
        guard tokenProvider != nil else {
            await refreshSnapshot()
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        var processedCount = 0
        var failedCountDuringRun = 0

        while connectivityMonitor.isOnline {
            let due = await queue.dueRecords()
            guard !due.isEmpty else { break }

            for record in due {
                guard connectivityMonitor.isOnline else { break }

                await queue.markExecuting(id: record.id)
                do {
                    let token = try await requireToken()
                    let mapping = try await execute(record: record, token: token)
                    await queue.markSucceeded(id: record.id, tempMapping: mapping)
                    processedCount += 1
                } catch {
                    failedCountDuringRun += 1
                    await queue.markFailed(id: record.id, reason: error.localizedDescription)
                }

                await refreshSnapshot()
            }
        }

        if failedCountDuringRun == 0, processedCount > 0 {
            lastSyncMessage = "Offline changes synced."
        } else if failedCountDuringRun > 0 {
            lastSyncMessage = "Synced with \(failedCountDuringRun) failed item\(failedCountDuringRun == 1 ? "" : "s")."
        }

        await refreshSnapshot()
    }

    private func handleConnectivityChange() async {
        await refreshSnapshot()
        guard connectivityMonitor.isOnline else { return }
        await flushPendingMutations()
    }

    private func executeOrQueue<T>(
        payload: OfflineMutationPayload,
        execute: @escaping (String) async throws -> (T, (String, String)?)
    ) async throws -> MutationDispatchResult<T> {
        if !connectivityMonitor.isOnline {
            return await queueNow(payload)
        }

        do {
            let token = try await requireToken()
            let (value, mapping) = try await execute(token)
            if let mapping {
                await queue.setTempIDMapping(tempID: mapping.0, serverID: mapping.1)
            }
            await refreshSnapshot()
            return .executed(value)
        } catch {
            guard shouldQueue(after: error) else {
                throw error
            }
            return await queueNow(payload)
        }
    }

    private func queueNow<T>(_ payload: OfflineMutationPayload) async -> MutationDispatchResult<T> {
        let record = await queue.enqueue(payload: payload)
        lastSyncMessage = "\(payload.debugLabel) saved offline."
        await refreshSnapshot()
        return .queued(operationID: record.id)
    }

    private func requireToken() async throws -> String {
        guard let tokenProvider else {
            throw RotaryAPIError.unauthenticated
        }
        return try await tokenProvider(false)
    }

    private func shouldQueue(after error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .timedOut, .internationalRoamingOff:
                return true
            default:
                break
            }
        }

        if let apiError = error as? RotaryAPIError {
            switch apiError {
            case .requestFailed(let statusCode, _, _, _):
                return statusCode >= 500
            case .invalidResponse:
                return true
            case .unauthenticated, .invalidURL:
                return false
            }
        }

        return false
    }

    private func refreshSnapshot() async {
        let snapshot = await queue.currentSnapshot()
        pendingCount = snapshot.pendingCount
        failedCount = snapshot.failedCount
        latestFailureReason = snapshot.latestFailureReason
        lastSuccessfulSyncAt = snapshot.lastSuccessfulSyncAt
    }

    private func execute(record: OfflineMutationRecord, token: String) async throws -> (String, String)? {
        let payload = record.payload

        switch payload.kind {
        case .sendMessage:
            guard let request = payload.sendMessage else { throw OfflineMutationExecutionError.invalidRecord(payload.kind) }
            let resolvedContactID = await queue.resolveID(request.contactId)
            _ = try await api.sendMessage(
                token: token,
                contactId: resolvedContactID,
                toNumber: request.toNumber,
                fromNumber: request.fromNumber,
                message: request.message
            )
            return nil

        case .updateThreads:
            guard let request = payload.updateThreads else { throw OfflineMutationExecutionError.invalidRecord(payload.kind) }
            let resolvedContactIDs = await resolveIDs(request.contactIds)
            _ = try await api.updateThreads(token: token, contactIds: resolvedContactIDs, action: request.action)
            return nil

        case .createContact:
            guard let request = payload.createContact else { throw OfflineMutationExecutionError.invalidRecord(payload.kind) }
            let response = try await api.createContact(
                token: token,
                name: request.name,
                phoneNumber: request.phoneNumber,
                email: request.email,
                company: request.company,
                fullAddress: request.fullAddress,
                avatarURL: request.avatarURL
            )
            return (request.tempID, response.contact.id)

        case .updateContact:
            guard let request = payload.updateContact else { throw OfflineMutationExecutionError.invalidRecord(payload.kind) }
            let resolvedContactID = try await resolveRequiredID(request.contactId)
            _ = try await api.updateContact(
                token: token,
                contactId: resolvedContactID,
                name: request.name,
                phoneNumber: request.phoneNumber,
                email: request.email,
                company: request.company,
                fullAddress: request.fullAddress,
                avatarURL: request.avatarURL
            )
            return nil

        case .createFolder:
            guard let request = payload.createFolder else { throw OfflineMutationExecutionError.invalidRecord(payload.kind) }
            let response = try await api.createFolderDetailed(
                token: token,
                name: request.name,
                description: request.description,
                color: request.color
            )
            if let folderID = response.folder?.id {
                return (request.tempID, folderID)
            }
            return nil

        case .updateFolder:
            guard let request = payload.updateFolder else { throw OfflineMutationExecutionError.invalidRecord(payload.kind) }
            let resolvedFolderID = try await resolveRequiredID(request.folderId)
            _ = try await api.updateFolderDetailed(
                token: token,
                folderId: resolvedFolderID,
                name: request.name,
                description: request.description,
                color: request.color
            )
            return nil

        case .createWorkspace:
            guard let request = payload.createWorkspace else { throw OfflineMutationExecutionError.invalidRecord(payload.kind) }
            try await api.createWorkspace(token: token, businessName: request.businessName)
            return nil

        case .createAgent:
            guard let request = payload.createAgent else { throw OfflineMutationExecutionError.invalidRecord(payload.kind) }
            let resolvedFolderID = await queue.resolveID(request.folderId)
            let agent = try await api.createAgent(
                token: token,
                name: request.name,
                purpose: request.purpose,
                voiceName: request.voiceName,
                voiceProfileId: request.voiceProfileId,
                thinkingMode: request.thinkingMode,
                folderId: resolvedFolderID
            )
            return (request.tempID, agent.id)

        case .provisionOwnerLine:
            guard let request = payload.provisionOwnerLine else { throw OfflineMutationExecutionError.invalidRecord(payload.kind) }
            let line = try await api.provisionOwnerLine(token: token, phoneNumber: request.phoneNumber)
            return (request.tempID, line.id)

        case .provisionAgentLine:
            guard let request = payload.provisionAgentLine else { throw OfflineMutationExecutionError.invalidRecord(payload.kind) }
            let resolvedAgentID = try await resolveRequiredID(request.agentId)
            let resolvedFolderID = await queue.resolveID(request.folderId)
            _ = try await api.provisionAgentLine(token: token, agentId: resolvedAgentID, folderId: resolvedFolderID)
            return nil

        case .updateCallScreening:
            guard let request = payload.updateCallScreening else { throw OfflineMutationExecutionError.invalidRecord(payload.kind) }
            _ = try await api.updateCallScreeningSettings(token: token, enabled: request.enabled)
            return nil

        case .registerDevice:
            guard let request = payload.registerDevice else { throw OfflineMutationExecutionError.invalidRecord(payload.kind) }
            _ = try await api.registerDevice(
                token: token,
                pushToken: request.pushToken,
                voipPushToken: request.voipPushToken,
                clientReady: request.clientReady
            )
            return nil

        case .sendAgentConversationMessage:
            guard let request = payload.sendAgentConversationMessage else { throw OfflineMutationExecutionError.invalidRecord(payload.kind) }
            let resolvedAgentID = try await resolveRequiredID(request.agentId)
            let resolvedAttachmentIDs = try await resolveRequiredIDs(request.attachmentIds)
            _ = try await api.sendAgentConversationMessage(
                token: token,
                agentId: resolvedAgentID,
                message: request.message,
                attachmentIds: resolvedAttachmentIDs,
                thinkingMode: request.thinkingMode
            )
            return nil

        case .uploadAgentAttachment:
            guard let request = payload.uploadAgentAttachment else { throw OfflineMutationExecutionError.invalidRecord(payload.kind) }
            let resolvedAgentID = try await resolveRequiredID(request.agentId)
            let response = try await api.uploadAgentAttachment(
                token: token,
                agentId: resolvedAgentID,
                payload: request.payload.toUploadPayload
            )
            if let tempID = request.tempID {
                return (tempID, response.attachment.id)
            }
            return nil
        }
    }

    private func resolveIDs(_ ids: [String]) async -> [String] {
        var resolved: [String] = []
        resolved.reserveCapacity(ids.count)
        for id in ids {
            resolved.append(await queue.resolveID(id) ?? id)
        }
        return resolved
    }

    private func resolveRequiredIDs(_ ids: [String]) async throws -> [String] {
        var resolved: [String] = []
        resolved.reserveCapacity(ids.count)
        for id in ids {
            resolved.append(try await resolveRequiredID(id))
        }
        return resolved
    }

    private func resolveRequiredID(_ maybeTempID: String) async throws -> String {
        let resolved = await queue.resolveID(maybeTempID) ?? maybeTempID
        if isTemporaryReference(resolved) {
            throw OfflineMutationExecutionError.awaitingDependency(maybeTempID)
        }
        return resolved
    }

    private func isTemporaryReference(_ value: String) -> Bool {
        value.hasPrefix("temp-") || value.hasPrefix("temp:")
    }
}

enum OfflineMutationExecutionError: LocalizedError {
    case invalidRecord(OfflineMutationKind)
    case awaitingDependency(String)

    var errorDescription: String? {
        switch self {
        case .invalidRecord(let kind):
            return "Offline mutation record is invalid for \(kind.rawValue)."
        case .awaitingDependency(let id):
            return "Waiting for dependent sync item to resolve \(id)."
        }
    }
}
