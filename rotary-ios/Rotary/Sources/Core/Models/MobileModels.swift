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
    var threadId: String? = nil
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
    var contactLanguage: String? = nil
    var userLanguage: String? = nil
    var translationMode: String? = nil
    var translationEnabled: Bool? = nil

    var id: String { threadId ?? contactId }
}

struct MobileThreadMessage: Codable, Identifiable {
    let id: String
    let direction: String
    let fromNumber: String?
    let toNumber: String?
    let content: String
    let renderedContent: String?
    let renderStatus: String?
    let displayContent: String?
    let originalContent: String?
    let translatedContent: String?
    let sourceLanguage: String?
    let targetLanguage: String?
    let translationStatus: String?
    let translationProvider: String?
    let status: String
    let sentAt: String
    let rawPayload: [String: JSONValue]
}

struct MobileThreadParticipant: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let phoneNumber: String?
    let kind: String?
    let isAgent: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayName
        case phoneNumber
        case phone
        case kind
        case type
        case isAgent
        case is_agent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let resolvedName = (
            try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .displayName)
            ?? container.decodeIfPresent(String.self, forKey: .phoneNumber)
            ?? container.decodeIfPresent(String.self, forKey: .phone)
            ?? "Unknown Participant"
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedPhone = (
            try container.decodeIfPresent(String.self, forKey: .phoneNumber)
            ?? container.decodeIfPresent(String.self, forKey: .phone)
        )?.trimmingCharacters(in: .whitespacesAndNewlines)

        name = resolvedName.isEmpty ? "Unknown Participant" : resolvedName
        phoneNumber = resolvedPhone?.isEmpty == true ? nil : resolvedPhone

        let decodedKind = (
            try container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresent(String.self, forKey: .type)
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        kind = decodedKind?.isEmpty == true ? nil : decodedKind

        isAgent = try container.decodeIfPresent(Bool.self, forKey: .isAgent)
            ?? container.decodeIfPresent(Bool.self, forKey: .is_agent)

        let decodedID = try container.decodeIfPresent(String.self, forKey: .id)
        let fallbackID = [name, phoneNumber, kind]
            .compactMap { $0 }
            .joined(separator: "|")
        id = decodedID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? decodedID!.trimmingCharacters(in: .whitespacesAndNewlines)
            : (fallbackID.isEmpty ? UUID().uuidString : fallbackID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(isAgent, forKey: .isAgent)
    }
}

struct MobileThreadDetail: Codable {
    struct SocialProfile: Codable, Hashable, Identifiable {
        let label: String
        let url: String

        var id: String { "\(label)|\(url)" }
    }

    struct Contact: Codable {
        var threadId: String? = nil
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
        let contactLanguage: String?
        let userLanguage: String?
        let translationMode: String?
        let translationEnabled: Bool?
    }

    let contact: Contact
    let participants: [MobileThreadParticipant]?
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
    var liveAssistEligible: Bool? = nil
    var playbackKind: String? = nil
    var playbackStatus: String? = nil
    var executionMode: String? = nil
    let intakePayload: [String: JSONValue]
    let createdAt: String
    let updatedAt: String
}

extension MobileCall {
    var hasPlayableRecording: Bool {
        guard let recordingURL = recordingUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !recordingURL.isEmpty
        else {
            return false
        }

        if recordingURL.hasPrefix("/api/mobile/calls/recording") {
            return true
        }

        guard let url = URL(string: recordingURL),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false
        }
        return true
    }

    var playbackStatusResolved: String {
        let normalized = playbackStatus?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalized == "available" || normalized == "processing" || normalized == "absent" {
            return normalized ?? "absent"
        }
        if hasPlayableRecording {
            return "available"
        }
        if let status = transcriptStatus?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           ["processing", "in-progress", "in_progress", "queued", "pending"].contains(status) {
            return "processing"
        }
        return "absent"
    }

    var playbackKindResolved: String? {
        if let normalized = playbackKind?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           normalized == "voicemail" || normalized == "recording" {
            return normalized
        }

        let normalizedStatus = status.lowercased()
        if normalizedStatus.contains("voicemail")
            || screeningOutcome?.lowercased().contains("voicemail") == true
            || twilioAnsweredBy?.contains("machine") == true {
            return "voicemail"
        }

        if hasPlayableRecording || playbackStatusResolved != "absent" {
            return "recording"
        }

        return nil
    }

    var playbackSectionTitle: String? {
        guard let playbackKindResolved else { return nil }
        return playbackKindResolved == "voicemail" ? "Voicemail" : "Recording"
    }

    var shouldShowPlaybackControl: Bool {
        playbackStatusResolved == "available" && hasPlayableRecording
    }

    var playbackStatusMessage: String? {
        guard playbackSectionTitle != nil else { return nil }
        guard !shouldShowPlaybackControl else { return nil }

        switch playbackStatusResolved {
        case "processing":
            return "Audio is still processing."
        case "absent":
            return playbackKindResolved == "voicemail"
                ? "No voicemail audio is available for this call."
                : "No call recording is available for this call."
        default:
            return nil
        }
    }

    var transcriptStatusResolved: String {
        if transcript?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return "complete"
        }
        let normalized = transcriptStatus?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalized == "complete" || normalized == "processing" || normalized == "absent" {
            return normalized ?? "absent"
        }
        if playbackStatusResolved == "processing" {
            return "processing"
        }
        return "absent"
    }

    var summaryStatusMessage: String? {
        guard summary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false else {
            return nil
        }

        switch transcriptStatusResolved {
        case "processing":
            return "Summary is still processing."
        case "absent":
            return "Summary is not available for this call."
        default:
            return nil
        }
    }

    var transcriptStatusMessage: String? {
        guard transcript?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false else {
            return nil
        }

        switch transcriptStatusResolved {
        case "processing":
            return "Transcript is still processing."
        case "absent":
            return "Transcript is not available for this call."
        default:
            return nil
        }
    }

    var isVoicemailConversation: Bool {
        if playbackKindResolved == "voicemail" {
            return true
        }

        let normalizedStatus = status.lowercased()
        if normalizedStatus.contains("voicemail") {
            return true
        }

        if livePhase == .voicemail {
            return true
        }

        if screeningOutcome?.lowercased().contains("voicemail") == true {
            return true
        }

        if twilioAnsweredBy?.contains("machine") == true {
            return true
        }

        return false
    }

    var hasPlayableVoicemailRecording: Bool {
        playbackKindResolved == "voicemail" && shouldShowPlaybackControl
    }

    var shouldLoadVoicemailDetailRoute: Bool {
        playbackKindResolved == "voicemail" || isVoicemailConversation
    }
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
    let ttsModelFamily: String?
    let expressiveModeSupported: Bool?
    let realtimeSupported: Bool?
}

extension MobileVoicePreset {
    var normalizedProvider: String {
        provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var rotaryEligibilityMetadataPresent: Bool {
        resolvedModelFamily != nil || resolvedExpressiveModeSupported != nil
    }

    var rotaryV3ExpressiveEligible: Bool {
        normalizedProvider == "elevenlabs"
            && resolvedIsV3Conversational == true
            && resolvedExpressiveModeSupported == true
    }

    var rotaryVoiceEligibilityMessage: String {
        guard normalizedProvider == "elevenlabs" else {
            return "Rotary requires an ElevenLabs voice preset."
        }

        guard rotaryEligibilityMetadataPresent else {
            return "Voice preset metadata is incomplete. Rotary requires ElevenLabs v3 expressive capability fields before creating an agent."
        }

        guard resolvedIsV3Conversational == true else {
            return "This voice is not marked as an ElevenLabs v3 conversational voice."
        }

        guard resolvedExpressiveModeSupported == true else {
            return "Expressive mode is not enabled for this voice."
        }

        return ""
    }

    var rotaryRealtimePriority: Int {
        var score = 0
        if resolvedRealtimeSupported == true {
            score += 2
        }
        let signature = rotaryLabelSignature
        if signature.contains("realtime") || signature.contains("real-time") {
            score += 2
        }
        if signature.contains("agent") || signature.contains("conversational") {
            score += 1
        }
        return score
    }

    private var resolvedModelFamily: String? {
        firstNonEmpty(
            ttsModelFamily,
            labelValue(for: "tts_model_family"),
            labelValue(for: "model_family"),
            labelValue(for: "modelFamily")
        )?.lowercased()
    }

    private var resolvedExpressiveModeSupported: Bool? {
        if let expressiveModeSupported {
            return expressiveModeSupported
        }

        return firstBooleanValue(
            labelValue(for: "expressive_mode_supported"),
            labelValue(for: "supports_expressive_mode"),
            labelValue(for: "expressive_mode"),
            labelValue(for: "expressive")
        )
    }

    private var resolvedRealtimeSupported: Bool? {
        if let realtimeSupported {
            return realtimeSupported
        }

        return firstBooleanValue(
            labelValue(for: "realtime_supported"),
            labelValue(for: "supports_realtime"),
            labelValue(for: "real_time_supported")
        )
    }

    private var resolvedIsV3Conversational: Bool? {
        guard let resolvedModelFamily else {
            return nil
        }

        let normalized = resolvedModelFamily.lowercased()
        return normalized.contains("v3") && normalized.contains("conversational")
    }

    private var rotaryLabelSignature: String {
        let labelText = (labels ?? [:]).values.joined(separator: " ").lowercased()
        return [
            name.lowercased(),
            (category ?? "").lowercased(),
            (description ?? "").lowercased(),
            labelText,
        ]
        .joined(separator: " ")
    }

    private func labelValue(for key: String) -> String? {
        guard let value = labels?[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private func firstNonEmpty(_ values: String?...) -> String? {
        values.first { value in
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return false
            }
            return !trimmed.isEmpty
        } ?? nil
    }

    private func firstBooleanValue(_ values: String?...) -> Bool? {
        for value in values {
            guard let rawValue = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  !rawValue.isEmpty else {
                continue
            }

            switch rawValue {
            case "true", "yes", "1", "enabled", "supported":
                return true
            case "false", "no", "0", "disabled", "unsupported":
                return false
            default:
                continue
            }
        }
        return nil
    }
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
    let originalContent: String?
    let sourceLanguage: String?
    let targetLanguage: String?
    let wasTranslated: Bool?
    let deliveryStatus: String?
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

struct MobileThreadLanguageResponse: Codable {
    let contactId: String
    let contactLanguage: String?
    let userLanguage: String?
    let translationMode: String?
    let translationEnabled: Bool?
}

struct MobileCallsPayload: Codable {
    let calls: [MobileCall]
}

struct MobilePreviewHighlightRange: Decodable, Hashable {
    let start: Int
    let length: Int?
    let end: Int?

    private enum CodingKeys: String, CodingKey {
        case start
        case length
        case end
        case location
        case offset
    }

    init(start: Int, length: Int?, end: Int?) {
        self.start = start
        self.length = length
        self.end = end
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let resolvedStart =
            try container.decodeIfPresent(Int.self, forKey: .start)
            ?? container.decodeIfPresent(Int.self, forKey: .location)
            ?? container.decodeIfPresent(Int.self, forKey: .offset)
            ?? 0

        start = max(resolvedStart, 0)
        length = try container.decodeIfPresent(Int.self, forKey: .length)
        end = try container.decodeIfPresent(Int.self, forKey: .end)
    }
}

struct MobileCallSearchResultItem: Decodable, Identifiable {
    let type: String
    let matchField: String
    let preview: String
    let previewHighlightedRanges: [MobilePreviewHighlightRange]
    let call: MobileCall

    var id: String { call.id }

    private enum CodingKeys: String, CodingKey {
        case type
        case matchField
        case preview
        case previewText
        case previewSnippet
        case previewHighlightedRanges
        case call
        case voicemail
    }

    init(
        type: String,
        matchField: String,
        preview: String,
        previewHighlightedRanges: [MobilePreviewHighlightRange],
        call: MobileCall
    ) {
        self.type = type
        self.matchField = matchField
        self.preview = preview
        self.previewHighlightedRanges = previewHighlightedRanges
        self.call = call
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = (try container.decodeIfPresent(String.self, forKey: .type)) ?? "call"
        matchField = (try container.decodeIfPresent(String.self, forKey: .matchField)) ?? "summary"
        previewHighlightedRanges =
            (try container.decodeIfPresent([MobilePreviewHighlightRange].self, forKey: .previewHighlightedRanges))
            ?? []

        if let nestedCall = try container.decodeIfPresent(MobileCall.self, forKey: .call) {
            call = nestedCall
        } else if let nestedVoicemail = try container.decodeIfPresent(MobileCall.self, forKey: .voicemail) {
            call = nestedVoicemail
        } else {
            call = try MobileCall(from: decoder)
        }

        func trimmedNonEmpty(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        let fallbackPreview =
            trimmedNonEmpty(call.summary)
            ?? trimmedNonEmpty(call.transcript)
            ?? trimmedNonEmpty(call.contactPhone)
            ?? trimmedNonEmpty(call.toNumber)
            ?? trimmedNonEmpty(call.fromNumber)
            ?? ""

        let previewValue = try container.decodeIfPresent(String.self, forKey: .preview)
        let previewSnippetValue = try container.decodeIfPresent(String.self, forKey: .previewSnippet)
        let previewTextValue = try container.decodeIfPresent(String.self, forKey: .previewText)
        preview = previewValue ?? previewSnippetValue ?? previewTextValue ?? fallbackPreview
    }
}

struct MobileCallSearchPayload: Decodable {
    let results: [MobileCallSearchResultItem]

    private enum CodingKeys: String, CodingKey {
        case results
        case calls
        case voicemails
    }

    init(results: [MobileCallSearchResultItem]) {
        self.results = results
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let results = try container.decodeIfPresent([MobileCallSearchResultItem].self, forKey: .results) {
            self.results = results
            return
        }

        let calls = try container.decodeIfPresent([MobileCallSearchResultItem].self, forKey: .calls) ?? []
        let voicemails = try container.decodeIfPresent([MobileCallSearchResultItem].self, forKey: .voicemails) ?? []
        results = (calls + voicemails).sorted { $0.call.createdAt > $1.call.createdAt }
    }
}

struct MobileSendMessageResponse: Codable {
    struct TranslationSnapshot: Codable {
        let displayContent: String?
        let originalContent: String?
        let translatedContent: String?
        let sourceLanguage: String?
        let targetLanguage: String?
        let translationStatus: String?
        let translationProvider: String?
    }

    struct ThreadTranslationSnapshot: Codable {
        let contactLanguage: String?
        let userLanguage: String?
        let translationMode: String?
        let translationEnabled: Bool?
    }

    let success: Bool
    let messageId: String?
    let contactId: String?
    let translation: TranslationSnapshot?
    let threadTranslation: ThreadTranslationSnapshot?
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
        let pushToken: String?
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

    var isLiveAssistEligible: Bool {
        if let liveAssistEligible {
            return liveAssistEligible
        }

        let callMode = (
            intakeString("call_mode")
                ?? intakeString("callMode")
        )?.lowercased()
        if callMode?.hasPrefix("mobile_live_assist_join") == true {
            return false
        }

        let payloadOwnerType = (
            intakeString("line_owner_type")
                ?? intakeString("lineOwnerType")
        )?.lowercased()
        let payloadRole = (
            intakeString("line_role")
                ?? intakeString("lineRole")
        )?.lowercased()
        let payloadAgentId = intakeString("voice_agent_id")
            ?? intakeString("voiceAgentId")
            ?? intakeString("agent_id")
            ?? intakeString("agentId")

        return payloadOwnerType == "agent"
            || payloadRole == "agent"
            || trimmedNonEmpty(payloadAgentId) != nil
            || trimmedNonEmpty(agentId) != nil
    }

    var shouldShowLiveSteerControls: Bool {
        isLiveAssistEligible && executionModeResolved == "agent_autonomous"
    }

    var executionModeResolved: String {
        if let executionMode = executionMode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           executionMode == "agent_autonomous" || executionMode == "user_bridge" {
            return executionMode
        }

        let callMode = (
            intakeString("call_mode")
                ?? intakeString("callMode")
        )?.lowercased()
        if callMode?.hasPrefix("mobile_live_assist_join") == true {
            return "user_bridge"
        }

        return isLiveAssistEligible ? "agent_autonomous" : "user_bridge"
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
