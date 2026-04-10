import Foundation

enum RotaryDeepLink: Equatable {
    case messagesThread(threadID: String)
    case agentConversation(agentID: String)
    case calls
    case callsLiveAssist(callID: String?)
    case settings

    var routingKey: String {
        switch self {
        case let .messagesThread(threadID):
            return "messages:\(threadID)"
        case let .agentConversation(agentID):
            return "agents:\(agentID)"
        case .calls:
            return "calls"
        case let .callsLiveAssist(callID):
            return "calls-live-assist:\(callID ?? "latest")"
        case .settings:
            return "settings"
        }
    }

    static func parse(_ url: URL) -> RotaryDeepLink? {
        guard url.scheme?.lowercased() == "rotary" else {
            return nil
        }

        let host = (url.host ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard host != "auth", host != "debug" else {
            return nil
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        func normalizedValue(_ rawValue: String?) -> String? {
            guard let rawValue else { return nil }
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        func queryValue(named name: String) -> String? {
            normalizedValue(
                components?.queryItems?
                    .first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?
                    .value
            )
        }

        func finalPathValue() -> String? {
            normalizedValue(pathComponents.last)
        }

        switch host {
        case "messages", "message":
            if let threadID = queryValue(named: "threadId")
                ?? queryValue(named: "threadID")
                ?? queryValue(named: "contactId")
                ?? finalPathValue() {
                return .messagesThread(threadID: threadID)
            }
            return nil
        case "agents", "agent":
            if let agentID = queryValue(named: "agentId")
                ?? queryValue(named: "agentID")
                ?? finalPathValue() {
                return .agentConversation(agentID: agentID)
            }
            return nil
        case "calls", "call":
            let liveAssistRequested = pathComponents.first?.lowercased() == "live-assist"
                || queryValue(named: "liveAssist") == "1"
                || queryValue(named: "openLiveAssist") == "1"
                || queryValue(named: "callId") != nil
                || queryValue(named: "callSid") != nil

            if liveAssistRequested {
                let callID = queryValue(named: "callId")
                    ?? queryValue(named: "callSid")
                    ?? finalPathValue()
                return .callsLiveAssist(callID: callID)
            }

            return .calls
        case "settings":
            return .settings
        default:
            return nil
        }
    }
}
