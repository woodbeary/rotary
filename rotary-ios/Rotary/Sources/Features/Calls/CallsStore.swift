import Foundation
import Observation

struct RotaryCallContact: Identifiable, Hashable {
    let phoneNumber: String
    let name: String
    let sourceLine: String?
    let latestPreview: String?

    var id: String { phoneNumber }
}

@MainActor
@Observable
final class CallsStore {
    private let api: RotaryAPIClient
    private let tokenProvider: RotaryTokenProvider

    private(set) var allCalls: [MobileCall]
    private(set) var voicemails: [MobileCall]
    private(set) var contacts: [RotaryCallContact] = []
    private(set) var missedCallCount = 0
    private(set) var isLoadingCalls = false
    private(set) var isLoadingVoicemail = false
    private(set) var hasLoadedCalls = false
    private(set) var hasLoadedVoicemail = false
    private(set) var loadError: String?
    private(set) var voicemailLoadError: String?

    private var threadPreview: [MobileThreadSummary]
    private var agents: [MobileAgent]
    private var ownerLinePhoneNumber: String?
    private var agentCallMap: [String: [MobileCall]] = [:]
    private var lineCallMap: [String: [MobileCall]] = [:]
    private var historyByPhone: [String: [MobileCall]] = [:]

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
        self.allCalls = Self.sortedCalls(bootstrap.callPreview)
        self.voicemails = Self.sortedCalls(bootstrap.callPreview.filter(Self.isVoicemailLike))
        self.threadPreview = bootstrap.threadPreview
        self.agents = bootstrap.agents
        self.ownerLinePhoneNumber = bootstrap.ownerLine?.phoneNumber ?? bootstrap.capabilities.defaultMainLine
        rebuildDerivedData()
    }

    func applyBootstrap(_ bootstrap: MobileBootstrapReadyState) {
        threadPreview = bootstrap.threadPreview
        agents = bootstrap.agents
        ownerLinePhoneNumber = bootstrap.ownerLine?.phoneNumber ?? bootstrap.capabilities.defaultMainLine

        allCalls = Self.mergeCalls(existing: allCalls, incoming: bootstrap.callPreview)
        voicemails = Self.mergeCalls(
            existing: voicemails,
            incoming: bootstrap.callPreview.filter(Self.isVoicemailLike)
        )

        rebuildDerivedData()
    }

    func refreshCallSurfaces(forceRefresh: Bool = false) async {
        if Self.usesLocalDebugBootstrap {
            hasLoadedCalls = true
            hasLoadedVoicemail = true
            loadError = nil
            voicemailLoadError = nil
            rebuildDerivedData()
            return
        }

        async let callsResult = loadCalls(forceRefresh: forceRefresh)
        async let voicemailResult = loadVoicemails(forceRefresh: forceRefresh)
        _ = await (callsResult, voicemailResult)
    }

    @discardableResult
    func loadCalls(forceRefresh: Bool = false) async -> Bool {
        if Self.usesLocalDebugBootstrap {
            hasLoadedCalls = true
            loadError = nil
            rebuildDerivedData()
            return true
        }

        if isLoadingCalls {
            return false
        }

        isLoadingCalls = true
        defer { isLoadingCalls = false }

        do {
            let loadedCalls = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.listCalls(token: token, forceRefresh: forceRefresh)
            }

            allCalls = Self.sortedCalls(loadedCalls)
            hasLoadedCalls = true
            loadError = nil
            rebuildDerivedData()
            return true
        } catch {
            loadError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func loadVoicemails(forceRefresh: Bool = false) async -> Bool {
        if Self.usesLocalDebugBootstrap {
            hasLoadedVoicemail = true
            voicemailLoadError = nil
            rebuildDerivedData()
            return true
        }

        if isLoadingVoicemail {
            return false
        }

        isLoadingVoicemail = true
        defer { isLoadingVoicemail = false }

        do {
            let payload = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.voicemailList(token: token, forceRefresh: forceRefresh)
            }
            voicemails = Self.sortedCalls(payload.voicemails)
            hasLoadedVoicemail = true
            voicemailLoadError = nil
            rebuildDerivedData()
            return true
        } catch {
            voicemailLoadError = error.localizedDescription
            return false
        }
    }

    func history(for phoneNumber: String) -> [MobileCall] {
        let normalized = Self.normalizedPhone(phoneNumber)
        guard let normalized else { return [] }
        return historyByPhone[normalized] ?? []
    }

    func relatedCalls(for agent: MobileAgent) -> [MobileCall] {
        var related = agentCallMap[agent.id] ?? []
        if let lineId = agent.assignedLineId {
            related.append(contentsOf: lineCallMap[lineId] ?? [])
        }
        var uniqueByID: [String: MobileCall] = [:]
        for call in related {
            uniqueByID[call.id] = call
        }
        return uniqueByID.values.sorted { $0.createdAt > $1.createdAt }
    }

    private func rebuildDerivedData() {
        missedCallCount = allCalls.filter { $0.status.lowercased().contains("missed") }.count

        var seen = Set<String>()
        var derivedContacts: [RotaryCallContact] = []
        var nextHistory: [String: [MobileCall]] = [:]
        var nextAgentCallMap: [String: [MobileCall]] = [:]
        var nextLineCallMap: [String: [MobileCall]] = [:]

        for call in allCalls {
            if let agentId = call.agentId {
                nextAgentCallMap[agentId, default: []].append(call)
            }
            if let lineId = call.lineId {
                nextLineCallMap[lineId, default: []].append(call)
            }
            if let phoneNumber = Self.normalizedPhone(call.contactPhone ?? call.toNumber ?? call.fromNumber) {
                nextHistory[phoneNumber, default: []].append(call)
            }
        }

        for thread in threadPreview {
            guard let phoneNumber = Self.normalizedPhone(thread.contactPhone),
                  seen.insert(phoneNumber).inserted else {
                continue
            }

            derivedContacts.append(
                RotaryCallContact(
                    phoneNumber: phoneNumber,
                    name: thread.contactName,
                    sourceLine: thread.preferredFromNumber,
                    latestPreview: thread.preview
                )
            )
        }

        for call in allCalls {
            guard let phoneNumber = Self.normalizedPhone(call.contactPhone ?? call.toNumber ?? call.fromNumber),
                  seen.insert(phoneNumber).inserted else {
                continue
            }

            derivedContacts.append(
                RotaryCallContact(
                    phoneNumber: phoneNumber,
                    name: call.contactName,
                    sourceLine: ownerLinePhoneNumber,
                    latestPreview: call.summary ?? call.transcript
                )
            )
        }

        contacts = derivedContacts
        historyByPhone = nextHistory.mapValues { $0.sorted { $0.createdAt > $1.createdAt } }
        agentCallMap = nextAgentCallMap.mapValues { $0.sorted { $0.createdAt > $1.createdAt } }
        lineCallMap = nextLineCallMap.mapValues { $0.sorted { $0.createdAt > $1.createdAt } }
    }

    private static func sortedCalls(_ calls: [MobileCall]) -> [MobileCall] {
        calls.sorted { $0.createdAt > $1.createdAt }
    }

    private static func mergeCalls(existing: [MobileCall], incoming: [MobileCall]) -> [MobileCall] {
        guard !existing.isEmpty else {
            return sortedCalls(incoming)
        }
        guard !incoming.isEmpty else {
            return sortedCalls(existing)
        }

        var merged = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for call in incoming {
            merged[call.id] = call
        }

        return sortedCalls(Array(merged.values))
    }

    private static func normalizedPhone(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func isVoicemailLike(_ call: MobileCall) -> Bool {
        let status = call.status.lowercased()
        return status.contains("voicemail")
            || call.recordingUrl != nil
            || call.summary != nil
            || call.transcript != nil
    }
}
