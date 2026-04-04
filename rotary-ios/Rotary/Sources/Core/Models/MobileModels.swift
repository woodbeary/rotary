import Foundation

struct MobileCapabilityFlags: Codable {
    let outboundSmsEnabled: Bool
    let callbackBridgeEnabled: Bool
    let mobileVoiceEnabled: Bool
    let mobileIncomingVoipReady: Bool
    let campaignMessagingUnlocked: Bool
    let lineProvisioningEnabled: Bool
    let numberSearchEnabled: Bool?
    let aiChatEnabled: Bool?
    let liveAssistEnabled: Bool?
    let defaultMainLine: String
    let defaultSecondaryLine: String
}

struct MobileLine: Codable, Identifiable {
    let id: String
    let phoneNumber: String
    let status: String
    let role: String
    let market: String?
    let friendlyName: String?
    let metadata: [String: JSONValue]
    let ownershipScope: String
    let answerMode: String
    let missedCallPolicy: String
    let screenUnknownCallers: Bool
    let outboundSmsAllowed: Bool
    let outboundCallsAllowed: Bool
    let mobileIncomingReady: Bool
    let ownerType: String?
    let agentId: String?
    let folderId: String?
    let provisioningStatus: String?
    let createdAt: String
    let updatedAt: String
}

struct MobileProvisioningJob: Codable, Identifiable {
    let key: String
    let title: String
    let status: String
    let detail: String

    var id: String { key }
}

struct MobileAiAvailability: Codable {
    let reasoningProvider: String
    let speechProvider: String
    let thinkingModes: [String]
    let liveAssistEnabled: Bool
    let voiceCloneEnabled: Bool
}

struct MobileAgentFolderSummary: Codable, Identifiable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let color: String?
    let agentCount: Int
    let lineCount: Int
    let latestActivityAt: String?
    let memberAgentIds: [String]
    let recentCallIds: [String]
    let recentThreadContactIds: [String]
}

struct MobileThreadSummary: Codable, Identifiable {
    let contactId: String
    let contactName: String
    let contactPhone: String?
    let contactEmail: String?
    let preview: String
    let lastDirection: String
    let lastStatus: String
    let lastMessageAt: String?
    let preferredFromNumber: String
    let unreadCount: Int?
    let isDeleted: Bool?
    let isSpam: Bool?

    var id: String { contactId }
}

struct MobileThreadMessage: Codable, Identifiable {
    let id: String
    let direction: String
    let fromNumber: String?
    let toNumber: String?
    let content: String
    let status: String
    let sentAt: String
    let rawPayload: [String: JSONValue]
}

struct MobileThreadDetail: Codable {
    struct SocialProfile: Codable, Hashable, Identifiable {
        let label: String
        let url: String

        var id: String { "\(label)|\(url)" }
    }

    struct Contact: Codable {
        let id: String
        let name: String
        let phone: String?
        let email: String?
        let lastContactedAt: String?
        let lastActivitySummary: String?
        let avatarUrl: String?
        let company: String?
        let fullAddress: String?
        let website: String?
        let cityName: String?
        let latitude: Double?
        let longitude: Double?
        let socialProfiles: [SocialProfile]?
        let preferredFromNumber: String
    }

    let contact: Contact
    let messages: [MobileThreadMessage]
}

struct MobileCall: Codable, Identifiable {
    let id: String
    let callSid: String
    let contactId: String?
    let contactName: String
    let contactPhone: String?
    let lineId: String?
    let fromNumber: String?
    let toNumber: String?
    let status: String
    let durationSeconds: Int?
    let screeningOutcome: String?
    let transferOutcome: String?
    let recordingUrl: String?
    let transcript: String?
    let summary: String?
    let agentId: String?
    let folderId: String?
    let transcriptStatus: String?
    let summarySmsSentAt: String?
    let readAt: String?
    let intakePayload: [String: JSONValue]
    let createdAt: String
    let updatedAt: String
}

enum MobileLiveCallPhase: Equatable {
    case calling
    case ringing
    case connected
    case voicemail
    case busy
    case noAnswer
    case failed
    case ended
}

struct MobileAgent: Codable, Identifiable {
    let id: String
    let name: String
    let slug: String
    let systemInstruction: String
    let voiceName: String
    let voiceProvider: String?
    let voiceProfileId: String?
    let isActive: Bool
    let screeningMode: String
    let recordingMode: String
    let timezone: String
    let smsSummaryTarget: String?
    let transferEnabled: Bool
    let assignedLineId: String?
    let assignedPhoneNumber: String?
    let folderId: String?
    let folderName: String?
    let thinkingMode: String?
    let provisioningStatus: String?
    let createdAt: String
    let updatedAt: String
}

struct MobileOrganization: Codable {
    let id: String
    let name: String
    let clerkOrgID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case clerkOrgID = "clerk_org_id"
    }
}

struct MobileWorkspaceSummary: Codable {
    let id: String
    let name: String
    let onboardingState: String
}

struct MobileTransferDestination: Codable, Identifiable {
    let id: String
    let label: String
    let phoneNumber: String
    let priority: Int
    let active: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case phoneNumber = "phone_number"
        case priority
        case active
    }
}

struct MobileSession: Codable {
    let userId: String
    let orgId: String
}

struct MobileBootstrapReadyState: Codable {
    let status: String
    let session: MobileSession
    let org: MobileOrganization?
    let workspace: MobileWorkspaceSummary?
    let capabilities: MobileCapabilityFlags
    let answerMode: String
    let ownerCellNumber: String?
    let ownerLine: MobileLine?
    let lines: [MobileLine]
    let folders: [MobileAgentFolderSummary]?
    let provisioningJobs: [MobileProvisioningJob]?
    let ai: MobileAiAvailability?
    let transferDestinations: [MobileTransferDestination]
    let threadPreview: [MobileThreadSummary]
    let callPreview: [MobileCall]
    let agents: [MobileAgent]
}

struct MobileStatusNotice: Codable {
    let status: String
    let title: String
    let message: String
    let detail: String?
    let code: String?
    let supportEmail: String?
    let org: MobileOrganization?
    let provisioningJobs: [MobileProvisioningJob]?
    let ai: MobileAiAvailability?
    let capabilities: MobileCapabilityFlags?
}

struct MobileErrorState: Codable {
    let status: String
    let title: String
    let message: String
    let detail: String?
    let code: String?
    let supportEmail: String?
    let canRetry: Bool?
}

enum MobileBootstrapPayload {
    case ready(MobileBootstrapReadyState)
    case setupRequired(MobileStatusNotice)
    case pendingAccess(MobileStatusNotice)
    case error(MobileErrorState)

    static func decode(from data: Data, decoder: JSONDecoder = .rotary) throws -> MobileBootstrapPayload {
        let rawObject = try JSONSerialization.jsonObject(with: data)
        let raw = rawObject as? [String: Any] ?? [:]
        let status = (raw["status"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch status {
        case "setup_required":
            return .setupRequired(try decoder.decode(MobileStatusNotice.self, from: data))
        case "pending_access":
            return .pendingAccess(try decoder.decode(MobileStatusNotice.self, from: data))
        case "error":
            return .error(try decoder.decode(MobileErrorState.self, from: data))
        default:
            if raw["session"] != nil, raw["capabilities"] != nil, raw["lines"] != nil {
                return .ready(try decoder.decode(MobileBootstrapReadyState.self, from: data))
            }

            return .error(
                MobileErrorState(
                    status: "error",
                    title: "Unable to load workspace",
                    message: "The server response did not match the Rotary mobile contract.",
                    detail: raw["detail"] as? String ?? raw["message"] as? String,
                    code: "invalid_bootstrap_payload",
                    supportEmail: raw["supportEmail"] as? String ?? raw["support_email"] as? String,
                    canRetry: true
                )
            )
        }
    }
}

struct MobileVoiceTokenResponse: Codable {
    let enabled: Bool
    let incomingEnabled: Bool?
    let reason: String?
    let reasonCode: String?
    let incomingReason: String?
    let incomingReasonCode: String?
    let token: String?
    let identity: String?
    let capabilities: [String: JSONValue]?
}

struct MobileAgentChatResponse: Codable {
    let reply: String
    let thinkingMode: String
    let provider: String
    let grounding: [String: JSONValue]
}

struct MobileVoicePreset: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let provider: String
    let category: String?
    let description: String?
    let previewUrl: String?
    let labels: [String: String]?
}

struct MobileVoicePresetsResponse: Codable {
    let voices: [MobileVoicePreset]
    let provider: String
    let live: Bool
}

struct MobileAgentConversationAttachment: Codable, Identifiable, Hashable {
    let id: String
    let fileName: String
    let mimeType: String?
    let fileSize: Int?
    let attachmentKind: String
    let extractedText: String?
    let previewUrl: String?
    let createdAt: String
}

struct MobileAgentConversationMessage: Codable, Identifiable, Hashable {
    let id: String
    let role: String
    let content: String
    let provider: String?
    let thinkingMode: String?
    let messageKind: String
    let createdAt: String
    let attachments: [MobileAgentConversationAttachment]
}

struct MobileAgentConversationSummary: Codable {
    let id: String
    let agentId: String
    let languageCode: String?
    let lastActivityAt: String
}

struct MobileAgentConversationPayload: Codable {
    struct AgentSummary: Codable {
        let id: String
        let name: String
        let voiceName: String
        let voiceProvider: String?
        let voiceProfileId: String?
        let thinkingMode: String?
        let assignedLineId: String?
    }

    let conversation: MobileAgentConversationSummary
    let agent: AgentSummary
    let messages: [MobileAgentConversationMessage]
}

struct MobileAgentConversationMessageResponse: Codable {
    let message: MobileAgentConversationMessage
    let conversation: MobileAgentConversationSummary
}

struct MobileContactSearchResult: Codable, Identifiable, Hashable {
    let id: String
    let kind: String
    let name: String
    let phoneNumber: String?
    let subtitle: String?
}

struct MobileContactSearchPayload: Codable {
    let results: [MobileContactSearchResult]
}

struct MobileCreatedContact: Codable, Identifiable {
    let id: String
    let name: String
    let phone: String?
    let email: String?
    let avatarUrl: String?
    let company: String?
    let fullAddress: String?
}

struct MobileCreatedContactResponse: Codable {
    let contact: MobileCreatedContact
}

struct MobileThreadFilterCounts: Codable {
    let all: Int
    let knownSenders: Int
    let spam: Int
    let recentlyDeleted: Int
    let unread: Int
}

struct MobileThreadBulkUpdateResponse: Codable {
    let success: Bool
    let action: String
    let count: Int
}

struct MobileCallDetailPayload: Codable {
    let call: MobileCall
    let relatedCalls: [MobileCall]
}

struct MobileVoicemailListPayload: Codable {
    let voicemails: [MobileCall]
}

struct MobileVoicemailDetailPayload: Codable {
    let voicemail: MobileCall
    let relatedCalls: [MobileCall]
}

struct MobileCallScreeningSettings: Codable {
    let enabled: Bool
    let lineId: String
    let phoneNumber: String
}

struct MobileAgentAttachmentUploadResponse: Codable {
    let attachment: MobileAgentConversationAttachment
}

struct MobileLiveAssistResponse: Codable {
    let callId: String
    let intentSummary: String
    let suggestedNext: String
    let steeringOptions: [String]
    let transcript: String
    let provider: String
}

struct MobileCallJoinContext: Codable {
    let callMode: String
    let conferenceName: String?
    let muted: Bool
    let takeOver: Bool
}

struct MobileCallControlResponse: Codable {
    let success: Bool
    let action: String
    let callId: String
    let conferenceName: String?
    let joinContext: MobileCallJoinContext?
}

struct MobileCallSteerResponse: Codable {
    let success: Bool
    let callId: String
    let applied: String
}

struct MobileSearchNumber: Codable, Identifiable {
    let phoneNumber: String
    let friendlyName: String?
    let locality: String?
    let region: String?
    let country: String?
    let capabilities: [String: JSONValue]

    var id: String { phoneNumber }
}

struct MobileSearchLineResponse: Codable {
    let numbers: [MobileSearchNumber]
}

struct MobileProvisionLineResponse: Codable {
    let voiceNumber: MobileLine
}

struct MobileCreateAgentResponse: Codable {
    let agent: MobileAgent
}

struct MobileCreateFolderResponse: Codable {
    let folder: MobileAgentFolderSummary?
}

struct MobileFoldersPayload: Codable {
    let folders: [MobileAgentFolderSummary]
}

struct MobileAgentsPayload: Codable {
    let agents: [MobileAgent]
    let folders: [MobileAgentFolderSummary]
}

struct MobileThreadsPayload: Codable {
    let threads: [MobileThreadSummary]
}

struct MobileCallsPayload: Codable {
    let calls: [MobileCall]
}

struct MobileSendMessageResponse: Codable {
    let success: Bool
    let messageId: String?
    let contactId: String?
}

struct MobileCallbackResponse: Codable {
    let success: Bool?
    let callSid: String?
    let campaignId: String?
    let leadId: String?
    let bridgeState: String?
}

struct DeviceRegistrationResponse: Codable {
    struct Registration: Codable {
        let id: String
        let userId: String
        let orgId: String
        let lineCount: Int
        let platform: String
        let clientReady: Bool
        let voipPushToken: String?
    }

    let registration: Registration
}

struct EmptyPayload: Codable {}

enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

private func trimmedNonEmpty(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

extension JSONValue {
    var stringValue: String? {
        switch self {
        case let .string(value):
            return trimmedNonEmpty(value)
        case let .number(value):
            return String(value)
        case let .bool(value):
            return value ? "true" : "false"
        case .object, .array, .null:
            return nil
        }
    }

    var objectValue: [String: JSONValue]? {
        guard case let .object(value) = self else { return nil }
        return value
    }

    var arrayValue: [JSONValue]? {
        guard case let .array(value) = self else { return nil }
        return value
    }
}

extension MobileCall {
    private func intakeString(_ key: String) -> String? {
        intakePayload[key]?.stringValue
    }

    var twilioParentCallSid: String? {
        intakeString("twilio_parent_call_sid")
            ?? intakeString("twilio_call_sid")
            ?? intakeString("call_sid")
            ?? trimmedNonEmpty(callSid)
    }

    var twilioChildCallSid: String? {
        intakeString("twilio_child_call_sid")
    }

    var twilioAnsweredBy: String? {
        intakeString("twilio_answered_by")?.lowercased()
    }

    var liveStatusCode: String? {
        if let twilioAnsweredBy {
            if twilioAnsweredBy.contains("machine") {
                return "voicemail"
            }
            if twilioAnsweredBy == "fax" {
                return "failed"
            }
        }

        let rawStatus = (
            intakeString("last_status")
                ?? intakeString("operator_call_status")
                ?? trimmedNonEmpty(status)
        )?.lowercased()

        switch rawStatus {
        case "queued", "initiated", "connecting", "started_connecting":
            return "calling"
        case "ringing":
            return "ringing"
        case "answered", "in-progress", "in_progress", "connected", "active", "live_connected":
            return "connected"
        case "voicemail":
            return "voicemail"
        case "busy":
            return "busy"
        case "no-answer", "no_answer", "missed":
            return "no_answer"
        case "failed", "canceled", "cancelled":
            return "failed"
        case "completed":
            return "ended"
        case let value?:
            if value.contains("voicemail") {
                return "voicemail"
            }
            return value
        case nil:
            return nil
        }
    }

    var livePhase: MobileLiveCallPhase? {
        switch liveStatusCode {
        case "calling":
            return .calling
        case "ringing":
            return .ringing
        case "connected":
            return .connected
        case "voicemail":
            return .voicemail
        case "busy":
            return .busy
        case "no_answer":
            return .noAnswer
        case "failed":
            return .failed
        case "ended":
            return .ended
        default:
            return nil
        }
    }

    var liveStatusTitle: String? {
        switch livePhase {
        case .calling:
            return "Calling"
        case .ringing:
            return "Ringing"
        case .connected:
            return "On Call"
        case .voicemail:
            return "Voicemail"
        case .busy:
            return "Busy"
        case .noAnswer:
            return "No Answer"
        case .failed:
            return "Call Failed"
        case .ended:
            return "Call Ended"
        case nil:
            return nil
        }
    }

    var isLiveSessionTerminal: Bool {
        switch livePhase {
        case .voicemail, .busy, .noAnswer, .failed, .ended:
            return true
        case .calling, .ringing, .connected, .none:
            return false
        }
    }

    func matchesAnyCallSID(_ candidates: [String?]) -> Bool {
        let normalizedCandidates = Set(
            candidates
                .compactMap(trimmedNonEmpty)
                .map { $0.lowercased() }
        )
        guard !normalizedCandidates.isEmpty else { return false }

        let callCandidates = [
            twilioParentCallSid,
            twilioChildCallSid,
            callSid,
        ]
        .compactMap(trimmedNonEmpty)
        .map { $0.lowercased() }

        return callCandidates.contains { normalizedCandidates.contains($0) }
    }

    func matchesPhoneNumber(_ candidate: String?) -> Bool {
        guard let candidate else { return false }
        let normalizedCandidate = candidate.filter(\.isNumber)
        guard !normalizedCandidate.isEmpty else { return false }

        let callNumbers = [
            contactPhone,
            toNumber,
            fromNumber,
            intakeString("twilio_to_number"),
            intakeString("twilio_from_number"),
            intakeString("external_number"),
        ]
        .compactMap(trimmedNonEmpty)
        .map { $0.filter(\.isNumber) }

        return callNumbers.contains(normalizedCandidate)
    }

    func wasCreated(near referenceDate: Date, tolerance: TimeInterval = 180) -> Bool {
        let formatter = ISO8601DateFormatter()
        guard let createdAt = formatter.date(from: createdAt) else {
            return false
        }
        return abs(createdAt.timeIntervalSince(referenceDate)) <= tolerance
    }
}

extension JSONDecoder {
    nonisolated static var rotary: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

#if DEBUG
extension MobileBootstrapReadyState {
    static var debugFixture: MobileBootstrapReadyState? {
        let data = Data(debugFixtureJSON.utf8)
        return try? JSONDecoder.rotary.decode(MobileBootstrapReadyState.self, from: data)
    }

    private static let debugFixtureJSON = """
    {
      "status": "ready",
      "session": {
        "userId": "user_demo",
        "orgId": "org_demo"
      },
      "org": {
        "id": "org_demo",
        "name": "Rotary Demo",
        "clerk_org_id": "org_clerk_demo"
      },
      "workspace": {
        "id": "ws_demo",
        "name": "Rotary",
        "onboardingState": "complete"
      },
      "capabilities": {
        "outboundSmsEnabled": true,
        "callbackBridgeEnabled": true,
        "mobileVoiceEnabled": true,
        "mobileIncomingVoipReady": true,
        "campaignMessagingUnlocked": true,
        "lineProvisioningEnabled": true,
        "numberSearchEnabled": true,
        "aiChatEnabled": true,
        "liveAssistEnabled": true,
        "defaultMainLine": "+15551230001",
        "defaultSecondaryLine": "+15551230002"
      },
      "answerMode": "assistant",
      "ownerCellNumber": "+15559876543",
      "ownerLine": {
        "id": "line_owner",
        "phoneNumber": "+15551230001",
        "status": "active",
        "role": "owner",
        "market": "US",
        "friendlyName": "Main",
        "metadata": {},
        "ownershipScope": "workspace",
        "answerMode": "assistant",
        "missedCallPolicy": "voicemail",
        "screenUnknownCallers": false,
        "outboundSmsAllowed": true,
        "outboundCallsAllowed": true,
        "mobileIncomingReady": true,
        "ownerType": "user",
        "agentId": null,
        "folderId": null,
        "provisioningStatus": "ready",
        "createdAt": "2026-04-01T18:00:00Z",
        "updatedAt": "2026-04-01T18:00:00Z"
      },
      "lines": [
        {
          "id": "line_owner",
          "phoneNumber": "+15551230001",
          "status": "active",
          "role": "owner",
          "market": "US",
          "friendlyName": "Main",
          "metadata": {},
          "ownershipScope": "workspace",
          "answerMode": "assistant",
          "missedCallPolicy": "voicemail",
          "screenUnknownCallers": false,
          "outboundSmsAllowed": true,
          "outboundCallsAllowed": true,
          "mobileIncomingReady": true,
          "ownerType": "user",
          "agentId": null,
          "folderId": null,
          "provisioningStatus": "ready",
          "createdAt": "2026-04-01T18:00:00Z",
          "updatedAt": "2026-04-01T18:00:00Z"
        },
        {
          "id": "line_agent_1",
          "phoneNumber": "+15551230002",
          "status": "active",
          "role": "agent",
          "market": "US",
          "friendlyName": "Concierge",
          "metadata": {},
          "ownershipScope": "workspace",
          "answerMode": "assistant",
          "missedCallPolicy": "agent",
          "screenUnknownCallers": false,
          "outboundSmsAllowed": true,
          "outboundCallsAllowed": true,
          "mobileIncomingReady": true,
          "ownerType": "agent",
          "agentId": "agent_concierge",
          "folderId": "folder_ops",
          "provisioningStatus": "ready",
          "createdAt": "2026-04-01T18:00:00Z",
          "updatedAt": "2026-04-01T18:00:00Z"
        }
      ],
      "folders": [
        {
          "id": "folder_ops",
          "name": "Operations",
          "slug": "operations",
          "description": "Shared workspace ops",
          "color": "blue",
          "agentCount": 2,
          "lineCount": 1,
          "latestActivityAt": "2026-04-01T18:25:00Z",
          "memberAgentIds": ["agent_concierge", "agent_sales"],
          "recentCallIds": ["call_1", "call_2"],
          "recentThreadContactIds": ["contact_sarah", "contact_marcus"]
        }
      ],
      "provisioningJobs": [],
      "ai": {
        "reasoningProvider": "openai",
        "speechProvider": "twilio",
        "thinkingModes": ["fast", "balanced", "deep"],
        "liveAssistEnabled": true,
        "voiceCloneEnabled": true
      },
      "transferDestinations": [
        {
          "id": "transfer_owner",
          "label": "Jacob",
          "phone_number": "+15559876543",
          "priority": 1,
          "active": true
        }
      ],
      "threadPreview": [
        {
          "contactId": "contact_sarah",
          "contactName": "Sarah Chen",
          "contactPhone": "+15558675309",
          "contactEmail": "sarah@example.com",
          "preview": "Perfect, I can meet after 3.",
          "lastDirection": "inbound",
          "lastStatus": "delivered",
          "lastMessageAt": "2026-04-01T18:23:00Z",
          "preferredFromNumber": "+15551230001",
          "unreadCount": 2,
          "isDeleted": false,
          "isSpam": false
        },
        {
          "contactId": "contact_marcus",
          "contactName": "Marcus Reed",
          "contactPhone": "+15557778899",
          "contactEmail": null,
          "preview": "Need the invoice link when you get a chance.",
          "lastDirection": "outbound",
          "lastStatus": "sent",
          "lastMessageAt": "2026-04-01T17:58:00Z",
          "preferredFromNumber": "+15551230001",
          "unreadCount": 0,
          "isDeleted": false,
          "isSpam": false
        },
        {
          "contactId": "contact_unknown",
          "contactName": "Unknown Sender",
          "contactPhone": "+15550001119",
          "contactEmail": null,
          "preview": "Free estimate today",
          "lastDirection": "inbound",
          "lastStatus": "delivered",
          "lastMessageAt": "2026-04-01T15:40:00Z",
          "preferredFromNumber": "+15551230001",
          "unreadCount": 0,
          "isDeleted": false,
          "isSpam": true
        }
      ],
      "callPreview": [
        {
          "id": "call_1",
          "callSid": "CA111",
          "contactId": "contact_sarah",
          "contactName": "Sarah Chen",
          "contactPhone": "+15558675309",
          "lineId": "line_owner",
          "fromNumber": "+15558675309",
          "toNumber": "+15551230001",
          "status": "answered_inbound",
          "durationSeconds": 482,
          "screeningOutcome": "allowed",
          "transferOutcome": null,
          "recordingUrl": null,
          "transcript": null,
          "summary": "Follow-up about tomorrow's walkthrough.",
          "agentId": null,
          "folderId": null,
          "transcriptStatus": "complete",
          "summarySmsSentAt": null,
          "readAt": "2026-04-01T18:24:00Z",
          "intakePayload": {},
          "createdAt": "2026-04-01T18:20:00Z",
          "updatedAt": "2026-04-01T18:21:00Z"
        },
        {
          "id": "call_2",
          "callSid": "CA222",
          "contactId": "contact_marcus",
          "contactName": "Marcus Reed",
          "contactPhone": "+15557778899",
          "lineId": "line_owner",
          "fromNumber": "+15557778899",
          "toNumber": "+15551230001",
          "status": "missed_inbound",
          "durationSeconds": 0,
          "screeningOutcome": "allowed",
          "transferOutcome": null,
          "recordingUrl": null,
          "transcript": null,
          "summary": null,
          "agentId": null,
          "folderId": null,
          "transcriptStatus": null,
          "summarySmsSentAt": null,
          "readAt": null,
          "intakePayload": {},
          "createdAt": "2026-04-01T17:42:00Z",
          "updatedAt": "2026-04-01T17:42:00Z"
        },
        {
          "id": "call_3",
          "callSid": "CA333",
          "contactId": null,
          "contactName": "Unknown Caller",
          "contactPhone": "+15550001119",
          "lineId": "line_owner",
          "fromNumber": "+15550001119",
          "toNumber": "+15551230001",
          "status": "voicemail",
          "durationSeconds": 73,
          "screeningOutcome": "voicemail",
          "transferOutcome": null,
          "recordingUrl": "https://example.com/voicemail.mp3",
          "transcript": "Hey, just checking in about the quote.",
          "summary": "Caller asked for a pricing update.",
          "agentId": null,
          "folderId": null,
          "transcriptStatus": "complete",
          "summarySmsSentAt": null,
          "readAt": null,
          "intakePayload": {},
          "createdAt": "2026-04-01T16:11:00Z",
          "updatedAt": "2026-04-01T16:12:00Z"
        }
      ],
      "agents": [
        {
          "id": "agent_concierge",
          "name": "Concierge",
          "slug": "concierge",
          "systemInstruction": "Handle front-desk style intake and scheduling.",
          "voiceName": "Nova",
          "voiceProvider": "openai",
          "voiceProfileId": null,
          "isActive": true,
          "screeningMode": "assist",
          "recordingMode": "all",
          "timezone": "America/Los_Angeles",
          "smsSummaryTarget": "+15559876543",
          "transferEnabled": true,
          "assignedLineId": "line_agent_1",
          "assignedPhoneNumber": "+15551230002",
          "folderId": "folder_ops",
          "folderName": "Operations",
          "thinkingMode": "balanced",
          "provisioningStatus": "ready",
          "createdAt": "2026-04-01T18:00:00Z",
          "updatedAt": "2026-04-01T18:25:00Z"
        },
        {
          "id": "agent_sales",
          "name": "Sales Agent",
          "slug": "sales-agent",
          "systemInstruction": "Qualify leads and book demos.",
          "voiceName": "Arbor",
          "voiceProvider": "openai",
          "voiceProfileId": null,
          "isActive": true,
          "screeningMode": "assist",
          "recordingMode": "all",
          "timezone": "America/Los_Angeles",
          "smsSummaryTarget": "+15559876543",
          "transferEnabled": true,
          "assignedLineId": null,
          "assignedPhoneNumber": "+15551230003",
          "folderId": "folder_ops",
          "folderName": "Operations",
          "thinkingMode": "deep",
          "provisioningStatus": "ready",
          "createdAt": "2026-04-01T18:00:00Z",
          "updatedAt": "2026-04-01T17:40:00Z"
        }
      ]
    }
    """
}
#endif
