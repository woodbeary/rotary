import Foundation
import OSLog

struct RotaryUploadAttachmentPayload {
    let fileName: String
    let mimeType: String
    let data: Data
    let extractedText: String?
}

struct APIErrorEnvelope: Decodable {
    let error: String?
    let message: String?
    let detail: String?
    let code: String?
    let status: String?
    let kind: String?
    let supportEmail: String?
    let support_email: String?
    let decisionToken: String?
    let sourceLanguage: String?
    let targetLanguage: String?
}

enum RotaryAPIError: LocalizedError {
    case unauthenticated
    case invalidURL
    case requestFailed(statusCode: Int, message: String, code: String?, details: [String: String]?)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "No Clerk session is active."
        case .invalidURL:
            return "The API base URL is invalid."
        case let .requestFailed(_, message, _, _):
            return message
        case .invalidResponse:
            return "The server response was invalid."
        }
    }
}

private enum RotaryCacheKey {
    static let bootstrap = "bootstrap"
    static let threads = "threads"
    static let filters = "filters"
    static let calls = "calls"
    static let folders = "folders"
    static let voicemail = "voicemail"
    static let callScreening = "call-screening"
    static let voicePresets = "voice-presets"
    static let callsSearchPrefix = "calls-search"

    static func threadDetail(_ contactId: String, fromNumber: String? = nil) -> String {
        let normalizedFromNumber = fromNumber?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        if let normalizedFromNumber, !normalizedFromNumber.isEmpty {
            return "thread-detail:\(contactId):\(normalizedFromNumber)"
        }
        return "thread-detail:\(contactId)"
    }

    static func callDetail(_ callId: String) -> String {
        "call-detail:\(callId)"
    }

    static func voicemailDetail(_ voicemailId: String) -> String {
        "voicemail-detail:\(voicemailId)"
    }

    static func agentConversation(_ agentId: String) -> String {
        "agent-conversation:\(agentId)"
    }

    static func callsSearch(_ query: String) -> String {
        let normalized = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return "\(callsSearchPrefix):\(normalized)"
    }
}

private enum RotaryCacheTTL {
    static let bootstrap: TimeInterval = 45
    static let threads: TimeInterval = 45
    static let threadDetail: TimeInterval = 45
    static let filters: TimeInterval = 45
    static let calls: TimeInterval = 45
    static let callsSearch: TimeInterval = 12
    static let callDetail: TimeInterval = 60
    static let voicemail: TimeInterval = 60
    static let voicemailDetail: TimeInterval = 60
    static let folders: TimeInterval = 120
    static let voicePresets: TimeInterval = 1800
    static let agentConversation: TimeInterval = 180
    static let callScreening: TimeInterval = 120
}

private func makeDefaultRotarySession() -> URLSession {
    let configuration = URLSessionConfiguration.default
    configuration.waitsForConnectivity = true
    configuration.httpShouldSetCookies = true
    configuration.httpCookieAcceptPolicy = .always
    configuration.requestCachePolicy = .reloadRevalidatingCacheData
    configuration.urlCache = URLCache(
        memoryCapacity: 8 * 1024 * 1024,
        diskCapacity: 32 * 1024 * 1024
    )
    return URLSession(configuration: configuration)
}

@MainActor
final class RotaryAPIClient {
    private struct DebugLiveAssistState {
        var intentSummary: String
        var suggestedNext: String
        var steeringOptions: [String]
        var transcriptLines: [String]
        var provider: String
    }

    private let config: AppConfig
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let responseCache = RotaryResponseCache()
    private static var debugLiveAssistStatesByCallID: [String: DebugLiveAssistState] = [:]

    init(
        config: AppConfig? = nil,
        session: URLSession? = nil,
        decoder: JSONDecoder? = nil,
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.config = config ?? .shared
        self.session = session ?? makeDefaultRotarySession()
        self.decoder = decoder ?? .rotary
        self.encoder = encoder
    }

    func resetSessionCaches() async {
        await responseCache.removeAll()
        RotaryLogger.trace("API session caches cleared", category: "api")
    }

    func resolveMediaURL(_ value: String?) -> URL? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        if let absolute = URL(string: value),
           let scheme = absolute.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return absolute
        }

        guard let relative = URL(string: value, relativeTo: config.apiBaseURL) else {
            return nil
        }
        return relative.absoluteURL
    }

    func bootstrap(token: String, forceRefresh: Bool = false) async throws -> MobileBootstrapPayload {
        let data = try await cachedData(
            path: "/api/mobile/bootstrap",
            token: token,
            cacheKey: RotaryCacheKey.bootstrap,
            ttl: RotaryCacheTTL.bootstrap,
            forceRefresh: forceRefresh
        )
        return try MobileBootstrapPayload.decode(from: data, decoder: decoder)
    }

    func createWorkspace(token: String, businessName: String) async throws {
        struct Body: Encodable { let businessName: String
            enum CodingKeys: String, CodingKey { case businessName = "businessName" }
        }
        _ = try await request(
            path: "/api/mobile/workspace",
            method: "POST",
            token: token,
            body: Body(businessName: businessName),
            responseType: EmptyPayload.self
        )
        await invalidateCaches(
            RotaryCacheKey.bootstrap,
            RotaryCacheKey.threads,
            RotaryCacheKey.filters,
            RotaryCacheKey.calls,
            RotaryCacheKey.voicemail,
            RotaryCacheKey.folders
        )
    }

    func searchNumbers(token: String, areaCode: String, contains: String?) async throws -> [MobileSearchNumber] {
        struct Body: Encodable {
            let areaCode: String
            let contains: String?
            let countryCode: String
            let limit: Int
            let type: String
        }
        let response = try await request(
            path: "/api/mobile/lines/search",
            method: "POST",
            token: token,
            body: Body(areaCode: areaCode, contains: contains, countryCode: "US", limit: 8, type: "local"),
            responseType: MobileSearchLineResponse.self
        )
        return response.numbers
    }

    func provisionOwnerLine(token: String, phoneNumber: String) async throws -> MobileLine {
        struct Body: Encodable {
            let phoneNumber: String
            let role: String
        }
        let response = try await request(
            path: "/api/mobile/lines/provision",
            method: "POST",
            token: token,
            body: Body(phoneNumber: phoneNumber, role: "owner_main"),
            responseType: MobileProvisionLineResponse.self
        )
        await invalidateCaches(
            RotaryCacheKey.bootstrap,
            RotaryCacheKey.threads,
            RotaryCacheKey.filters,
            RotaryCacheKey.calls,
            RotaryCacheKey.voicemail,
            RotaryCacheKey.folders
        )
        return response.voiceNumber
    }

    func createAgent(
        token: String,
        name: String,
        purpose: String,
        voiceName: String,
        voiceProfileId: String?,
        thinkingMode: String,
        folderId: String?
    ) async throws -> MobileAgent {
        struct Body: Encodable {
            let name: String
            let purpose: String
            let voiceName: String
            let voiceProvider: String
            let voiceProfileId: String?
            let thinkingMode: String
            let folderId: String?
        }
        let response = try await request(
            path: "/api/mobile/agents",
            method: "POST",
            token: token,
            body: Body(
                name: name,
                purpose: purpose,
                voiceName: voiceName,
                voiceProvider: "elevenlabs",
                voiceProfileId: voiceProfileId,
                thinkingMode: thinkingMode,
                folderId: folderId
            ),
            responseType: MobileCreateAgentResponse.self
        )
        await invalidateCaches(RotaryCacheKey.bootstrap, RotaryCacheKey.folders)
        return response.agent
    }

    func provisionAgentLine(token: String, agentId: String, folderId: String?) async throws -> MobileLine {
        struct Body: Encodable {
            let role: String
            let agentId: String
            let folderId: String?
        }
        let response = try await request(
            path: "/api/mobile/lines/provision",
            method: "POST",
            token: token,
            body: Body(role: "agent", agentId: agentId, folderId: folderId),
            responseType: MobileProvisionLineResponse.self
        )
        await invalidateCaches(RotaryCacheKey.bootstrap, RotaryCacheKey.folders)
        return response.voiceNumber
    }

    func listThreads(token: String, forceRefresh: Bool = false) async throws -> [MobileThreadSummary] {
        let response = try await cachedRequest(
            path: "/api/mobile/messages/threads",
            token: token,
            cacheKey: RotaryCacheKey.threads,
            ttl: RotaryCacheTTL.threads,
            forceRefresh: forceRefresh,
            responseType: MobileThreadsPayload.self
        )
        return response.threads
    }

    func threadDetail(
        token: String,
        contactId: String,
        fromNumber: String? = nil,
        forceRefresh: Bool = false
    ) async throws -> MobileThreadDetail {
        let threadPath: String
        if let fromNumber = fromNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
           !fromNumber.isEmpty,
           let encoded = fromNumber.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            threadPath = "/api/mobile/messages/threads/\(contactId)?fromNumber=\(encoded)"
        } else {
            threadPath = "/api/mobile/messages/threads/\(contactId)"
        }

        return try await cachedRequest(
            path: threadPath,
            token: token,
            cacheKey: RotaryCacheKey.threadDetail(contactId, fromNumber: fromNumber),
            ttl: RotaryCacheTTL.threadDetail,
            forceRefresh: forceRefresh,
            responseType: MobileThreadDetail.self
        )
    }

    func sendMessage(
        token: String,
        contactId: String?,
        toNumber: String?,
        fromNumber: String,
        message: String,
        translationFailureAction: String? = nil,
        translationDecisionToken: String? = nil
    ) async throws -> MobileSendMessageResponse {
        struct Body: Encodable {
            let contactId: String?
            let toNumber: String?
            let fromNumber: String
            let message: String
            let translationFailureAction: String?
            let translationDecisionToken: String?
        }
        let response = try await request(
            path: "/api/mobile/messages/send",
            method: "POST",
            token: token,
            body: Body(
                contactId: contactId,
                toNumber: toNumber,
                fromNumber: fromNumber,
                message: message,
                translationFailureAction: translationFailureAction,
                translationDecisionToken: translationDecisionToken
            ),
            responseType: MobileSendMessageResponse.self
        )
        await invalidateCaches(RotaryCacheKey.threads, RotaryCacheKey.threadDetail(""), RotaryCacheKey.filters)
        return response
    }

    func updateThreadLanguage(
        token: String,
        contactId: String,
        contactLanguage: String?
    ) async throws -> MobileThreadLanguageResponse {
        struct Body: Encodable {
            let contactLanguage: String?
        }

        let response = try await request(
            path: "/api/mobile/messages/threads/\(contactId)/language",
            method: "PATCH",
            token: token,
            body: Body(contactLanguage: contactLanguage),
            responseType: MobileThreadLanguageResponse.self
        )

        await invalidateCaches(RotaryCacheKey.threads, RotaryCacheKey.threadDetail(contactId))
        return response
    }

    func listCalls(token: String, forceRefresh: Bool = false) async throws -> [MobileCall] {
        let response = try await cachedRequest(
            path: "/api/mobile/calls",
            token: token,
            cacheKey: RotaryCacheKey.calls,
            ttl: RotaryCacheTTL.calls,
            forceRefresh: forceRefresh,
            responseType: MobileCallsPayload.self
        )
        return response.calls
    }

    func searchCalls(token: String, query: String, forceRefresh: Bool = false) async throws -> MobileCallSearchPayload {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let encodedQuery = trimmedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return try await cachedRequest(
            path: "/api/mobile/calls/search?q=\(encodedQuery)",
            token: token,
            cacheKey: RotaryCacheKey.callsSearch(trimmedQuery),
            ttl: RotaryCacheTTL.callsSearch,
            forceRefresh: forceRefresh,
            responseType: MobileCallSearchPayload.self
        )
    }

    func startCallback(token: String, phoneNumber: String?, contactId: String?, fromNumber: String?) async throws -> MobileCallbackResponse {
        struct Body: Encodable {
            let contactId: String?
            let phoneNumber: String?
            let fromNumber: String?
        }
        return try await request(
            path: "/api/mobile/calls/callback",
            method: "POST",
            token: token,
            body: Body(contactId: contactId, phoneNumber: phoneNumber, fromNumber: fromNumber),
            responseType: MobileCallbackResponse.self
        )
    }

    func cancelCallback(token: String, callSid: String?) async throws -> MobileCallbackResponse {
        let path = callbackCancelPath(callSid: callSid)
        return try await request(
            path: path,
            method: "DELETE",
            token: token,
            responseType: MobileCallbackResponse.self
        )
    }

    func callbackCancelPath(callSid: String?) -> String {
        let basePath = "/api/mobile/calls/callback"
        guard let trimmedCallSid = callSid?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmedCallSid.isEmpty
        else {
            return basePath
        }

        var components = URLComponents()
        components.path = basePath
        components.queryItems = [URLQueryItem(name: "callSid", value: trimmedCallSid)]
        return components.string ?? basePath
    }

    func listFolders(token: String, forceRefresh: Bool = false) async throws -> [MobileAgentFolderSummary] {
        let response = try await cachedRequest(
            path: "/api/mobile/folders",
            token: token,
            cacheKey: RotaryCacheKey.folders,
            ttl: RotaryCacheTTL.folders,
            forceRefresh: forceRefresh,
            responseType: MobileFoldersPayload.self
        )
        return response.folders
    }

    func createFolder(token: String, name: String, description: String?, color: String?) async throws {
        _ = try await createFolderDetailed(
            token: token,
            name: name,
            description: description,
            color: color
        )
    }

    func createFolderDetailed(
        token: String,
        name: String,
        description: String?,
        color: String?
    ) async throws -> MobileCreateFolderResponse {
        struct Body: Encodable {
            let name: String
            let description: String?
            let color: String?
        }
        let response = try await request(
            path: "/api/mobile/folders",
            method: "POST",
            token: token,
            body: Body(name: name, description: description, color: color),
            responseType: MobileCreateFolderResponse.self
        )
        await invalidateCaches(RotaryCacheKey.bootstrap, RotaryCacheKey.folders)
        return response
    }

    func updateFolder(
        token: String,
        folderId: String,
        name: String,
        description: String? = nil,
        color: String? = nil
    ) async throws {
        _ = try await updateFolderDetailed(
            token: token,
            folderId: folderId,
            name: name,
            description: description,
            color: color
        )
    }

    func updateFolderDetailed(
        token: String,
        folderId: String,
        name: String,
        description: String? = nil,
        color: String? = nil
    ) async throws -> MobileCreateFolderResponse {
        struct Body: Encodable {
            let name: String
            let description: String?
            let color: String?
        }
        let response = try await request(
            path: "/api/mobile/folders/\(folderId)",
            method: "PATCH",
            token: token,
            body: Body(name: name, description: description, color: color),
            responseType: MobileCreateFolderResponse.self
        )
        await invalidateCaches(RotaryCacheKey.bootstrap, RotaryCacheKey.folders)
        return response
    }

    func chatWithAgent(token: String, agentId: String, message: String, thinkingMode: String) async throws -> MobileAgentChatResponse {
        struct Body: Encodable {
            let message: String
            let thinkingMode: String
        }
        return try await request(
            path: "/api/mobile/agents/\(agentId)/chat",
            method: "POST",
            token: token,
            body: Body(message: message, thinkingMode: thinkingMode),
            responseType: MobileAgentChatResponse.self
        )
    }

    func voicePresets(token: String, forceRefresh: Bool = false) async throws -> MobileVoicePresetsResponse {
        try await cachedRequest(
            path: "/api/mobile/voices/presets",
            token: token,
            cacheKey: RotaryCacheKey.voicePresets,
            ttl: RotaryCacheTTL.voicePresets,
            forceRefresh: forceRefresh,
            responseType: MobileVoicePresetsResponse.self
        )
    }

    func agentConversation(token: String, agentId: String, forceRefresh: Bool = false) async throws -> MobileAgentConversationPayload {
        try await cachedRequest(
            path: "/api/mobile/agents/\(agentId)/conversation",
            token: token,
            cacheKey: RotaryCacheKey.agentConversation(agentId),
            ttl: RotaryCacheTTL.agentConversation,
            forceRefresh: forceRefresh,
            responseType: MobileAgentConversationPayload.self
        )
    }

    func sendAgentConversationMessage(
        token: String,
        agentId: String,
        message: String?,
        attachmentIds: [String],
        thinkingMode: String
    ) async throws -> MobileAgentConversationMessageResponse {
        struct Body: Encodable {
            let message: String?
            let attachmentIds: [String]
            let thinkingMode: String
        }
        let response = try await request(
            path: "/api/mobile/agents/\(agentId)/conversation/messages",
            method: "POST",
            token: token,
            body: Body(message: message, attachmentIds: attachmentIds, thinkingMode: thinkingMode),
            responseType: MobileAgentConversationMessageResponse.self
        )
        await invalidateCaches(RotaryCacheKey.agentConversation(agentId))
        return response
    }

    func uploadAgentAttachment(
        token: String,
        agentId: String,
        payload: RotaryUploadAttachmentPayload
    ) async throws -> MobileAgentAttachmentUploadResponse {
        let boundary = "RotaryBoundary-\(UUID().uuidString)"
        var body = Data()

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField(name: "agentId", value: agentId)
        if let extractedText = payload.extractedText?.trimmingCharacters(in: .whitespacesAndNewlines), !extractedText.isEmpty {
            appendField(name: "extractedText", value: extractedText)
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(payload.fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(payload.mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(payload.data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let data = try await perform(
            path: "/api/mobile/uploads/agent-attachment",
            method: "POST",
            token: token,
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        await invalidateCaches(RotaryCacheKey.agentConversation(agentId))
        return try decoder.decode(MobileAgentAttachmentUploadResponse.self, from: data)
    }

    func liveAssist(token: String, callId: String) async throws -> MobileLiveAssistResponse {
#if DEBUG
        if callId.hasPrefix("debug-live-assist-") {
            let state = debugLiveAssistState(for: callId)
            return MobileLiveAssistResponse(
                callId: callId,
                intentSummary: state.intentSummary,
                suggestedNext: state.suggestedNext,
                steeringOptions: state.steeringOptions,
                transcript: state.transcriptLines.joined(separator: "\n"),
                provider: state.provider
            )
        }
#endif
        return try await request(path: "/api/mobile/calls/\(callId)/live-assist", method: "GET", token: token, responseType: MobileLiveAssistResponse.self)
    }

    func controlCall(token: String, callId: String, action: String) async throws -> MobileCallControlResponse {
#if DEBUG
        if callId.hasPrefix("debug-live-assist-") {
            var state = debugLiveAssistState(for: callId)
            state.transcriptLines.append("Control action: \(action.replacingOccurrences(of: "_", with: " "))")
            switch action {
            case "listen_only":
                state.suggestedNext = "Listening mode is enabled. Rotary is still collecting interpreter preferences."
            case "join":
                state.suggestedNext = "Joined the call. Confirming interpreter date, time, and billing contact."
            case "take_over":
                state.suggestedNext = "Take-over mode active. Provide a direct instruction for the next sentence."
            case "resume_agent":
                state.suggestedNext = "Agent resumed autonomous handling."
            case "leave":
                state.suggestedNext = "User left the bridge. Agent continues the interpreter request."
            case "end_call":
                state.suggestedNext = "Call ending. Drafting completion summary."
            default:
                break
            }
            saveDebugLiveAssistState(state, for: callId)
            let joinContext: MobileCallJoinContext? = switch action {
            case "listen_only":
                MobileCallJoinContext(callMode: "listen_only", conferenceName: "debug-live-assist", muted: true, takeOver: false)
            case "join":
                MobileCallJoinContext(callMode: "join", conferenceName: "debug-live-assist", muted: false, takeOver: false)
            case "take_over":
                MobileCallJoinContext(callMode: "take_over", conferenceName: "debug-live-assist", muted: false, takeOver: true)
            default:
                nil
            }
            return MobileCallControlResponse(
                success: true,
                action: action,
                callId: callId,
                conferenceName: "debug-live-assist",
                joinContext: joinContext
            )
        }
#endif
        struct Body: Encodable {
            let action: String
        }
        return try await request(
            path: "/api/mobile/calls/\(callId)/control",
            method: "POST",
            token: token,
            body: Body(action: action),
            responseType: MobileCallControlResponse.self
        )
    }

    func steerCall(
        token: String,
        callId: String,
        selectedOption: String?,
        customText: String?
    ) async throws -> MobileCallSteerResponse {
#if DEBUG
        if callId.hasPrefix("debug-live-assist-") {
            var state = debugLiveAssistState(for: callId)
            let trimmedOption = selectedOption?.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedCustom = customText?.trimmingCharacters(in: .whitespacesAndNewlines)
            let appliedValue = (trimmedOption?.isEmpty == false ? trimmedOption! : nil)
                ?? (trimmedCustom?.isEmpty == false ? trimmedCustom! : nil)
                ?? "No-op steer"

            state.transcriptLines.append("Steer: \(appliedValue)")

            let normalizedApplied = appliedValue.lowercased()
            if normalizedApplied.contains("interrupt") {
                state.suggestedNext = "Interrupting now: confirming interpreter availability before moving on."
            } else if normalizedApplied.contains("queue") {
                state.suggestedNext = "Queued. Rotary will ask this on the next turn."
            } else {
                state.suggestedNext = "Applied steer. Rotary is incorporating your direction."
            }

            state.steeringOptions = [
                "Confirm event date, location, and expected attendee count.",
                "Request certification and minimum booking window.",
                "Ask for callback text/email confirmation once the interpreter is assigned.",
            ]
            saveDebugLiveAssistState(state, for: callId)

            return MobileCallSteerResponse(
                success: true,
                callId: callId,
                applied: appliedValue
            )
        }
#endif
        struct Body: Encodable {
            let selectedOption: String?
            let customText: String?
        }
        return try await request(
            path: "/api/mobile/calls/\(callId)/steer",
            method: "POST",
            token: token,
            body: Body(selectedOption: selectedOption, customText: customText),
            responseType: MobileCallSteerResponse.self
        )
    }

#if DEBUG
    private func debugLiveAssistState(for callId: String) -> DebugLiveAssistState {
        if let cached = Self.debugLiveAssistStatesByCallID[callId] {
            return cached
        }

        let seeded = DebugLiveAssistState(
            intentSummary: "Book an ASL interpreter for Innovation Expo and send confirmation by text or email.",
            suggestedNext: "Ask Olivia to confirm interpreter availability for the event date.",
            steeringOptions: [
                "Ask if Olivia can place the interpreter request today.",
                "Confirm the best callback channel (text or email).",
                "Clarify interpreter duration and pricing details.",
            ],
            transcriptLines: [
                "Julia: Hi Olivia, I'm assisting Jacob and calling about Innovation Expo.",
                "Olivia: Sure, what support do you need for the event?",
                "Julia: We need to request a sign language interpreter and receive confirmation by text or email.",
            ],
            provider: "debug-local-live-assist"
        )
        Self.debugLiveAssistStatesByCallID[callId] = seeded
        return seeded
    }

    private func saveDebugLiveAssistState(_ state: DebugLiveAssistState, for callId: String) {
        Self.debugLiveAssistStatesByCallID[callId] = state
    }
#endif

    func registerDevice(
        token: String,
        pushToken: String?,
        voipPushToken: String?,
        clientReady: Bool
    ) async throws -> DeviceRegistrationResponse {
        struct Body: Encodable {
            let platform: String
            let pushToken: String?
            let voipPushToken: String?
            let deviceName: String?
            let appVersion: String?
            let clientReady: Bool
        }
        return try await request(
            path: "/api/mobile/devices",
            method: "POST",
            token: token,
            body: Body(
                platform: "ios",
                pushToken: pushToken,
                voipPushToken: voipPushToken,
                deviceName: ProcessInfo.processInfo.hostName,
                appVersion: "\(config.appVersion) (\(config.buildNumber))",
                clientReady: clientReady
            ),
            responseType: DeviceRegistrationResponse.self
        )
    }

    func voiceToken(token: String) async throws -> MobileVoiceTokenResponse {
        let environment = resolveIOSPushEnvironment()
        return try await request(
            path: "/api/mobile/voice/token?platform=ios&push_environment=\(environment)",
            method: "GET",
            token: token,
            responseType: MobileVoiceTokenResponse.self
        )
    }

    func resolveIOSPushEnvironment() -> String {
        switch config.iosPushEnvironment?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "development", "production":
            return config.iosPushEnvironment!.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        default:
#if DEBUG
            return "development"
#else
            return "production"
#endif
        }
    }

    func searchContacts(token: String, query: String) async throws -> MobileContactSearchPayload {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return try await request(
            path: "/api/mobile/contacts/search?q=\(encodedQuery)",
            method: "GET",
            token: token,
            responseType: MobileContactSearchPayload.self
        )
    }

    func createContact(
        token: String,
        name: String?,
        phoneNumber: String,
        email: String? = nil,
        company: String? = nil,
        fullAddress: String? = nil,
        avatarURL: String? = nil
    ) async throws -> MobileCreatedContactResponse {
        struct Body: Encodable {
            let name: String?
            let phoneNumber: String
            let email: String?
            let company: String?
            let fullAddress: String?
            let avatarUrl: String?
        }
        return try await request(
            path: "/api/mobile/contacts",
            method: "POST",
            token: token,
            body: Body(
                name: name,
                phoneNumber: phoneNumber,
                email: email,
                company: company,
                fullAddress: fullAddress,
                avatarUrl: avatarURL
            ),
            responseType: MobileCreatedContactResponse.self
        )
    }

    func updateContact(
        token: String,
        contactId: String,
        name: String?,
        phoneNumber: String?,
        email: String? = nil,
        company: String? = nil,
        fullAddress: String? = nil,
        avatarURL: String? = nil
    ) async throws -> MobileCreatedContactResponse {
        struct Body: Encodable {
            let name: String?
            let phoneNumber: String?
            let email: String?
            let company: String?
            let fullAddress: String?
            let avatarUrl: String?
        }

        return try await request(
            path: "/api/mobile/contacts/\(contactId)",
            method: "PATCH",
            token: token,
            body: Body(
                name: name,
                phoneNumber: phoneNumber,
                email: email,
                company: company,
                fullAddress: fullAddress,
                avatarUrl: avatarURL
            ),
            responseType: MobileCreatedContactResponse.self
        )
    }

    func messageFilters(token: String, forceRefresh: Bool = false) async throws -> MobileThreadFilterCounts {
        try await cachedRequest(
            path: "/api/mobile/messages/filters",
            token: token,
            cacheKey: RotaryCacheKey.filters,
            ttl: RotaryCacheTTL.filters,
            forceRefresh: forceRefresh,
            responseType: MobileThreadFilterCounts.self
        )
    }

    func updateThreads(
        token: String,
        contactIds: [String],
        action: String
    ) async throws -> MobileThreadBulkUpdateResponse {
        struct Body: Encodable {
            let contactIds: [String]
            let action: String
        }
        let response = try await request(
            path: "/api/mobile/messages/threads/bulk",
            method: "PATCH",
            token: token,
            body: Body(contactIds: contactIds, action: action),
            responseType: MobileThreadBulkUpdateResponse.self
        )
        await invalidateCaches(RotaryCacheKey.threads, RotaryCacheKey.threadDetail(""), RotaryCacheKey.filters)
        return response
    }

    func callDetail(token: String, callId: String, forceRefresh: Bool = false) async throws -> MobileCallDetailPayload {
        try await cachedRequest(
            path: "/api/mobile/calls/\(callId)",
            token: token,
            cacheKey: RotaryCacheKey.callDetail(callId),
            ttl: RotaryCacheTTL.callDetail,
            forceRefresh: forceRefresh,
            responseType: MobileCallDetailPayload.self
        )
    }

    func voicemailList(token: String, forceRefresh: Bool = false) async throws -> MobileVoicemailListPayload {
        try await cachedRequest(
            path: "/api/mobile/voicemail",
            token: token,
            cacheKey: RotaryCacheKey.voicemail,
            ttl: RotaryCacheTTL.voicemail,
            forceRefresh: forceRefresh,
            responseType: MobileVoicemailListPayload.self
        )
    }

    func voicemailDetail(token: String, voicemailId: String, forceRefresh: Bool = false) async throws -> MobileVoicemailDetailPayload {
        try await cachedRequest(
            path: "/api/mobile/voicemail/\(voicemailId)",
            token: token,
            cacheKey: RotaryCacheKey.voicemailDetail(voicemailId),
            ttl: RotaryCacheTTL.voicemailDetail,
            forceRefresh: forceRefresh,
            responseType: MobileVoicemailDetailPayload.self
        )
    }

    func callScreeningSettings(token: String, forceRefresh: Bool = false) async throws -> MobileCallScreeningSettings {
        try await cachedRequest(
            path: "/api/mobile/call-screening/settings",
            token: token,
            cacheKey: RotaryCacheKey.callScreening,
            ttl: RotaryCacheTTL.callScreening,
            forceRefresh: forceRefresh,
            responseType: MobileCallScreeningSettings.self
        )
    }

    func updateCallScreeningSettings(token: String, enabled: Bool) async throws -> MobileCallScreeningSettings {
        struct Body: Encodable {
            let enabled: Bool
        }
        let response = try await request(
            path: "/api/mobile/call-screening/settings",
            method: "POST",
            token: token,
            body: Body(enabled: enabled),
            responseType: MobileCallScreeningSettings.self
        )
        await invalidateCaches(RotaryCacheKey.callScreening, RotaryCacheKey.bootstrap)
        return response
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        token: String,
        responseType: Response.Type
    ) async throws -> Response {
        let data = try await perform(path: path, method: method, token: token)
        return try decoder.decode(Response.self, from: data)
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        token: String,
        body: Body,
        responseType: Response.Type
    ) async throws -> Response {
        let bodyData = try encoder.encode(body)
        let data = try await perform(path: path, method: method, token: token, body: bodyData)
        return try decoder.decode(Response.self, from: data)
    }

    private func cachedRequest<Response: Decodable>(
        path: String,
        token: String,
        cacheKey: String,
        ttl: TimeInterval,
        forceRefresh: Bool,
        responseType: Response.Type
    ) async throws -> Response {
        if !forceRefresh, let cached = await responseCache.data(for: cacheKey) {
            RotaryLogger.trace("API cache hit \(cacheKey)", category: "api")
            do {
                return try decoder.decode(Response.self, from: cached)
            } catch {
                // Schema changes can invalidate on-disk cache entries between app releases.
                RotaryLogger.trace(
                    "API cache decode miss \(cacheKey): \(error.localizedDescription)",
                    category: "api",
                    level: "warning"
                )
                await responseCache.invalidate(prefixes: [cacheKey])
            }
        }

        let data = try await perform(path: path, method: "GET", token: token)
        await responseCache.store(data, for: cacheKey, ttl: ttl)
        return try decoder.decode(Response.self, from: data)
    }

    private func cachedData(
        path: String,
        token: String,
        cacheKey: String,
        ttl: TimeInterval,
        forceRefresh: Bool
    ) async throws -> Data {
        if !forceRefresh, let cached = await responseCache.data(for: cacheKey) {
            RotaryLogger.trace("API cache hit \(cacheKey)", category: "api")
            return cached
        }

        let data = try await perform(path: path, method: "GET", token: token)
        await responseCache.store(data, for: cacheKey, ttl: ttl)
        return data
    }

    private func invalidateCaches(_ prefixes: String...) async {
        await responseCache.invalidate(prefixes: prefixes)
    }

    private func perform(
        path: String,
        method: String,
        token: String,
        body: Data? = nil,
        contentType: String = "application/json"
    ) async throws -> Data {
        guard let url = URL(string: path, relativeTo: config.apiBaseURL) else {
            throw RotaryAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let requestTraceId = "ios-\(UUID().uuidString.prefix(8))"
        request.setValue(requestTraceId, forHTTPHeaderField: "X-Rotary-Trace-ID")
        request.httpBody = body

        RotaryLogger.api.log("API \(method, privacy: .public) \(url.absoluteString, privacy: .public)")
        RotaryLogger.trace("API \(method) \(url.absoluteString) trace=\(requestTraceId)", category: "api")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            RotaryLogger.trace(
                "API transport failure \(method) \(url.absoluteString) trace=\(requestTraceId) error=\(error.localizedDescription)",
                category: "api",
                level: "error"
            )
            RotaryDiagnosticsReporter.send(
                severity: "error",
                stage: "api_transport",
                message: error.localizedDescription,
                context: [
                    "traceId": requestTraceId,
                    "method": method,
                    "path": path,
                ],
                authToken: token
            )
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            RotaryDiagnosticsReporter.send(
                severity: "error",
                stage: "api_invalid_response",
                message: "Invalid response for \(path)",
                context: [
                    "traceId": requestTraceId,
                    "method": method,
                    "path": path,
                ],
                authToken: token
            )
            throw RotaryAPIError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            RotaryLogger.trace(
                "API failure \(httpResponse.statusCode) \(url.absoluteString) trace=\(requestTraceId)",
                category: "api",
                level: "error"
            )
            let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data)
            RotaryDiagnosticsReporter.send(
                severity: httpResponse.statusCode >= 500 ? "error" : "warning",
                stage: "api_status_failure",
                message: envelope?.message ?? envelope?.error ?? "Request failed with status \(httpResponse.statusCode)",
                context: [
                    "traceId": requestTraceId,
                    "method": method,
                    "path": path,
                    "statusCode": "\(httpResponse.statusCode)",
                    "code": envelope?.code ?? envelope?.status ?? envelope?.kind ?? "unknown",
                ],
                authToken: token
            )
            throw RotaryAPIError.requestFailed(
                statusCode: httpResponse.statusCode,
                message: envelope?.message ?? envelope?.error ?? "Request failed with status \(httpResponse.statusCode)",
                code: envelope?.code ?? envelope?.status ?? envelope?.kind,
                details: [
                    "decisionToken": envelope?.decisionToken,
                    "sourceLanguage": envelope?.sourceLanguage,
                    "targetLanguage": envelope?.targetLanguage,
                ].compactMapValues { $0 }
            )
        }

        RotaryLogger.trace(
            "API success \(httpResponse.statusCode) \(url.absoluteString) trace=\(requestTraceId)",
            category: "api"
        )

        return data
    }
}
