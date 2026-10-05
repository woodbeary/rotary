import Foundation

enum MutationDispatchResult<T> {
    case executed(T)
    case queued(operationID: String)

    var queuedOperationID: String? {
        switch self {
        case .queued(let operationID):
            return operationID
        case .executed:
            return nil
        }
    }
}

enum OfflineMutationKind: String, Codable, CaseIterable {
    case sendMessage
    case updateThreads
    case createContact
    case updateContact
    case createFolder
    case updateFolder
    case createWorkspace
    case createAgent
    case provisionOwnerLine
    case provisionAgentLine
    case updateCallScreening
    case registerDevice
    case sendAgentConversationMessage
    case uploadAgentAttachment
}

enum OfflineMutationStatus: String, Codable {
    case pending
    case executing
    case failed
}

struct SendMessageMutationPayload: Codable, Hashable {
    let contactId: String?
    let toNumber: String?
    let fromNumber: String
    let message: String
}

struct UpdateThreadsMutationPayload: Codable, Hashable {
    let contactIds: [String]
    let action: String
}

struct CreateContactMutationPayload: Codable, Hashable {
    let tempID: String
    let name: String?
    let phoneNumber: String
    let email: String?
    let company: String?
    let fullAddress: String?
    let avatarURL: String?
}

struct UpdateContactMutationPayload: Codable, Hashable {
    let contactId: String
    let name: String?
    let phoneNumber: String?
    let email: String?
    let company: String?
    let fullAddress: String?
    let avatarURL: String?
}

struct CreateFolderMutationPayload: Codable, Hashable {
    let tempID: String
    let name: String
    let description: String?
    let color: String?
}

struct UpdateFolderMutationPayload: Codable, Hashable {
    let folderId: String
    let name: String
    let description: String?
    let color: String?
}

struct CreateWorkspaceMutationPayload: Codable, Hashable {
    let businessName: String
}

struct CreateAgentMutationPayload: Codable, Hashable {
    let tempID: String
    let name: String
    let purpose: String
    let voiceName: String
    let voiceProfileId: String?
    let thinkingMode: String
    let folderId: String?
}

struct ProvisionOwnerLineMutationPayload: Codable, Hashable {
    let tempID: String
    let phoneNumber: String
}

struct ProvisionAgentLineMutationPayload: Codable, Hashable {
    let agentId: String
    let folderId: String?
}

struct UpdateCallScreeningMutationPayload: Codable, Hashable {
    let enabled: Bool
}

struct RegisterDeviceMutationPayload: Codable, Hashable {
    let pushToken: String?
    let voipPushToken: String?
    let clientReady: Bool
}

struct SendAgentConversationMessageMutationPayload: Codable, Hashable {
    let agentId: String
    let message: String?
    let attachmentIds: [String]
    let thinkingMode: String
}

struct UploadAgentAttachmentMutationPayload: Codable, Hashable {
    let agentId: String
    let tempID: String?
    let payload: RotaryUploadAttachmentPayloadEnvelope
}

struct RotaryUploadAttachmentPayloadEnvelope: Codable, Hashable {
    let fileName: String
    let mimeType: String
    let data: Data
    let extractedText: String?

    init(payload: RotaryUploadAttachmentPayload) {
        fileName = payload.fileName
        mimeType = payload.mimeType
        data = payload.data
        extractedText = payload.extractedText
    }

    var toUploadPayload: RotaryUploadAttachmentPayload {
        RotaryUploadAttachmentPayload(
            fileName: fileName,
            mimeType: mimeType,
            data: data,
            extractedText: extractedText
        )
    }
}

struct OfflineMutationPayload: Codable, Hashable {
    let kind: OfflineMutationKind

    let sendMessage: SendMessageMutationPayload?
    let updateThreads: UpdateThreadsMutationPayload?
    let createContact: CreateContactMutationPayload?
    let updateContact: UpdateContactMutationPayload?
    let createFolder: CreateFolderMutationPayload?
    let updateFolder: UpdateFolderMutationPayload?
    let createWorkspace: CreateWorkspaceMutationPayload?
    let createAgent: CreateAgentMutationPayload?
    let provisionOwnerLine: ProvisionOwnerLineMutationPayload?
    let provisionAgentLine: ProvisionAgentLineMutationPayload?
    let updateCallScreening: UpdateCallScreeningMutationPayload?
    let registerDevice: RegisterDeviceMutationPayload?
    let sendAgentConversationMessage: SendAgentConversationMessageMutationPayload?
    let uploadAgentAttachment: UploadAgentAttachmentMutationPayload?

    private init(
        kind: OfflineMutationKind,
        sendMessage: SendMessageMutationPayload? = nil,
        updateThreads: UpdateThreadsMutationPayload? = nil,
        createContact: CreateContactMutationPayload? = nil,
        updateContact: UpdateContactMutationPayload? = nil,
        createFolder: CreateFolderMutationPayload? = nil,
        updateFolder: UpdateFolderMutationPayload? = nil,
        createWorkspace: CreateWorkspaceMutationPayload? = nil,
        createAgent: CreateAgentMutationPayload? = nil,
        provisionOwnerLine: ProvisionOwnerLineMutationPayload? = nil,
        provisionAgentLine: ProvisionAgentLineMutationPayload? = nil,
        updateCallScreening: UpdateCallScreeningMutationPayload? = nil,
        registerDevice: RegisterDeviceMutationPayload? = nil,
        sendAgentConversationMessage: SendAgentConversationMessageMutationPayload? = nil,
        uploadAgentAttachment: UploadAgentAttachmentMutationPayload? = nil
    ) {
        self.kind = kind
        self.sendMessage = sendMessage
        self.updateThreads = updateThreads
        self.createContact = createContact
        self.updateContact = updateContact
        self.createFolder = createFolder
        self.updateFolder = updateFolder
        self.createWorkspace = createWorkspace
        self.createAgent = createAgent
        self.provisionOwnerLine = provisionOwnerLine
        self.provisionAgentLine = provisionAgentLine
        self.updateCallScreening = updateCallScreening
        self.registerDevice = registerDevice
        self.sendAgentConversationMessage = sendAgentConversationMessage
        self.uploadAgentAttachment = uploadAgentAttachment
    }

    static func sendMessage(_ payload: SendMessageMutationPayload) -> OfflineMutationPayload {
        OfflineMutationPayload(kind: .sendMessage, sendMessage: payload)
    }

    static func updateThreads(_ payload: UpdateThreadsMutationPayload) -> OfflineMutationPayload {
        OfflineMutationPayload(kind: .updateThreads, updateThreads: payload)
    }

    static func createContact(_ payload: CreateContactMutationPayload) -> OfflineMutationPayload {
        OfflineMutationPayload(kind: .createContact, createContact: payload)
    }

    static func updateContact(_ payload: UpdateContactMutationPayload) -> OfflineMutationPayload {
        OfflineMutationPayload(kind: .updateContact, updateContact: payload)
    }

    static func createFolder(_ payload: CreateFolderMutationPayload) -> OfflineMutationPayload {
        OfflineMutationPayload(kind: .createFolder, createFolder: payload)
    }

    static func updateFolder(_ payload: UpdateFolderMutationPayload) -> OfflineMutationPayload {
        OfflineMutationPayload(kind: .updateFolder, updateFolder: payload)
    }

    static func createWorkspace(_ payload: CreateWorkspaceMutationPayload) -> OfflineMutationPayload {
        OfflineMutationPayload(kind: .createWorkspace, createWorkspace: payload)
    }

    static func createAgent(_ payload: CreateAgentMutationPayload) -> OfflineMutationPayload {
        OfflineMutationPayload(kind: .createAgent, createAgent: payload)
    }

    static func provisionOwnerLine(_ payload: ProvisionOwnerLineMutationPayload) -> OfflineMutationPayload {
        OfflineMutationPayload(kind: .provisionOwnerLine, provisionOwnerLine: payload)
    }

    static func provisionAgentLine(_ payload: ProvisionAgentLineMutationPayload) -> OfflineMutationPayload {
        OfflineMutationPayload(kind: .provisionAgentLine, provisionAgentLine: payload)
    }

    static func updateCallScreening(_ payload: UpdateCallScreeningMutationPayload) -> OfflineMutationPayload {
        OfflineMutationPayload(kind: .updateCallScreening, updateCallScreening: payload)
    }

    static func registerDevice(_ payload: RegisterDeviceMutationPayload) -> OfflineMutationPayload {
        OfflineMutationPayload(kind: .registerDevice, registerDevice: payload)
    }

    static func sendAgentConversationMessage(_ payload: SendAgentConversationMessageMutationPayload) -> OfflineMutationPayload {
        OfflineMutationPayload(kind: .sendAgentConversationMessage, sendAgentConversationMessage: payload)
    }

    static func uploadAgentAttachment(_ payload: UploadAgentAttachmentMutationPayload) -> OfflineMutationPayload {
        OfflineMutationPayload(kind: .uploadAgentAttachment, uploadAgentAttachment: payload)
    }

    var debugLabel: String {
        switch kind {
        case .sendMessage:
            return "Send message"
        case .updateThreads:
            return "Update threads"
        case .createContact:
            return "Create contact"
        case .updateContact:
            return "Update contact"
        case .createFolder:
            return "Create folder"
        case .updateFolder:
            return "Update folder"
        case .createWorkspace:
            return "Create workspace"
        case .createAgent:
            return "Create agent"
        case .provisionOwnerLine:
            return "Provision owner line"
        case .provisionAgentLine:
            return "Provision agent line"
        case .updateCallScreening:
            return "Update call screening"
        case .registerDevice:
            return "Register device"
        case .sendAgentConversationMessage:
            return "Send agent conversation"
        case .uploadAgentAttachment:
            return "Upload agent attachment"
        }
    }
}

struct OfflineMutationRecord: Codable, Hashable, Identifiable {
    let id: String
    let payload: OfflineMutationPayload
    let createdAt: Date
    var status: OfflineMutationStatus
    var attempts: Int
    var nextRetryAt: Date?
    var lastAttemptAt: Date?
    var failureReason: String?
}

struct OfflineQueueSnapshot: Hashable {
    let pendingCount: Int
    let failedCount: Int
    let totalCount: Int
    let latestFailureReason: String?
    let lastSuccessfulSyncAt: Date?
}
