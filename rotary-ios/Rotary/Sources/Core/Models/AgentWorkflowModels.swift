import Foundation

enum AgentComposerMode: String, Codable, CaseIterable, Hashable, Identifiable {
    case none
    case deepResearch
    case makeCall
    case webSearch
    case createImage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "None"
        case .deepResearch:
            return "Deep Research"
        case .makeCall:
            return "Make a Call"
        case .webSearch:
            return "Web Search"
        case .createImage:
            return "Create Image"
        }
    }

    var placeholder: String {
        switch self {
        case .none:
            return "Message Rotary"
        case .deepResearch:
            return "Get a detailed report"
        case .makeCall:
            return "Describe what the call should accomplish"
        case .webSearch:
            return "Search the web"
        case .createImage:
            return "Describe the image to generate"
        }
    }
}

enum AgentWorkflowWidgetState: Hashable {
    case idle
    case awaitingApproval(
        mode: AgentComposerMode,
        prompt: String,
        checklist: [String],
        payload: AgentWorkflowDraftPayload? = nil
    )
    case running(
        mode: AgentComposerMode,
        prompt: String,
        stepIndex: Int,
        steps: [String],
        detail: String,
        payload: AgentWorkflowRunningPayload? = nil
    )
    case cancelled(mode: AgentComposerMode)
    case completed(
        mode: AgentComposerMode,
        summary: String,
        details: [String],
        payload: AgentWorkflowCompletionPayload? = nil
    )
    case failed(mode: AgentComposerMode, message: String)

    var isRunning: Bool {
        if case .running = self {
            return true
        }
        return false
    }
}

struct AgentWorkflowQuestion: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let isRequired: Bool
}

struct AgentWorkflowTimelineEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let symbol: String
}

enum AgentWorkflowParticipantState: String, Hashable {
    case standby
    case active
    case left

    var label: String {
        switch self {
        case .standby:
            return "Standby"
        case .active:
            return "Live"
        case .left:
            return "Left"
        }
    }
}

struct AgentWorkflowParticipant: Identifiable, Hashable {
    let id: String
    let name: String
    let role: String
    let state: AgentWorkflowParticipantState
}

struct AgentWorkflowTranscriptLine: Identifiable, Hashable {
    let id: String
    let speaker: String
    let text: String
    let latencyMs: Int?
    let isTranslated: Bool
    let originalText: String?
    let sourceLanguage: String?
    let targetLanguage: String?
}

struct AgentWorkflowSteeringChoice: Identifiable, Hashable {
    let id: String
    let title: String
    let isRecommended: Bool
}

struct AgentWorkflowMetric: Identifiable, Hashable {
    let id: String
    let title: String
    let value: String
    let detail: String?
}

struct AgentCallOffer: Identifiable, Hashable {
    let id: String
    let providerName: String
    let phoneNumber: String
    let priceText: String
    let availabilityText: String
    let weatherSummary: String?
    let mapSummary: String?
    let notes: String
}

struct DeepResearchDraftPayload: Hashable {
    let skeletonQueries: [String]
    let approvalHint: String
}

struct DeepResearchRunningPayload: Hashable {
    let reasoningSnippet: String
    let sourceLabels: [String]
}

struct DeepResearchCompletionPayload: Hashable {
    let reportOutline: [String]
}

struct MakeCallDraftPayload: Hashable {
    let requiredQuestions: [AgentWorkflowQuestion]
}

struct MakeCallRunningPayload: Hashable {
    let timeline: [AgentWorkflowTimelineEvent]
    let phaseTitle: String
    let elapsedLabel: String
    let participants: [AgentWorkflowParticipant]
    let transcript: [AgentWorkflowTranscriptLine]
    let steeringChoices: [AgentWorkflowSteeringChoice]
    let latestSteeringText: String?
}

struct MakeCallCompletionPayload: Hashable {
    let offers: [AgentCallOffer]
    let recommendedOfferID: String?
    let highlights: [String]
    let metrics: [AgentWorkflowMetric]
    let reportText: String
}

enum AgentWorkflowDraftPayload: Hashable {
    case deepResearch(DeepResearchDraftPayload)
    case makeCall(MakeCallDraftPayload)
}

enum AgentWorkflowRunningPayload: Hashable {
    case deepResearch(DeepResearchRunningPayload)
    case makeCall(MakeCallRunningPayload)
}

enum AgentWorkflowCompletionPayload: Hashable {
    case deepResearch(DeepResearchCompletionPayload)
    case makeCall(MakeCallCompletionPayload)
}
