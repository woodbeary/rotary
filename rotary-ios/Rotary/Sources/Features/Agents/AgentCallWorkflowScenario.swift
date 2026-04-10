import Foundation

struct AgentCallWorkflowStage {
    let id: String
    let detail: String
    let phaseTitle: String
    let elapsedSeconds: Int
    let participants: [AgentWorkflowParticipant]
    let timeline: [AgentWorkflowTimelineEvent]
    let transcriptLines: [AgentWorkflowTranscriptLine]
    let steeringChoices: [AgentWorkflowSteeringChoice]
    let suggestedSteeringID: String?
    let traceMessage: String
    let renderDelayMs: UInt64
}

struct AgentCallWorkflowScenario {
    let id: String
    let prompt: String
    let stages: [AgentCallWorkflowStage]
    let offers: [AgentCallOffer]
    let recommendedOfferID: String?
    let highlights: [String]
    let metrics: [AgentWorkflowMetric]

    static func build(prompt: String) -> AgentCallWorkflowScenario {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestPrompt = trimmedPrompt.isEmpty ? "I need help scheduling service." : trimmedPrompt

        let roles = ParticipantRoles()
        let timelineBase: [AgentWorkflowTimelineEvent] = [
            AgentWorkflowTimelineEvent(
                id: "context",
                title: "Context capture",
                subtitle: "Collecting constraints and authorization",
                symbol: "checklist"
            ),
            AgentWorkflowTimelineEvent(
                id: "providers",
                title: "Provider discovery",
                subtitle: "Finding reachable candidates and routing",
                symbol: "list.bullet.rectangle.portrait"
            ),
            AgentWorkflowTimelineEvent(
                id: "calling",
                title: "Live call execution",
                subtitle: "Dialing, negotiating, and validating details",
                symbol: "phone.connection.fill"
            ),
            AgentWorkflowTimelineEvent(
                id: "summary",
                title: "Offer summary",
                subtitle: "Preparing comparable results",
                symbol: "chart.bar.doc.horizontal"
            ),
        ]

        let steeringChoices: [AgentWorkflowSteeringChoice] = [
            AgentWorkflowSteeringChoice(
                id: "budget-cap",
                title: "Cap quote at $95 before approval",
                isRecommended: true
            ),
            AgentWorkflowSteeringChoice(
                id: "expedite",
                title: "Prioritize earliest arrival even if pricier",
                isRecommended: false
            ),
            AgentWorkflowSteeringChoice(
                id: "confirm-license",
                title: "Require license + insurance confirmation",
                isRecommended: false
            ),
        ]

        let stages: [AgentCallWorkflowStage] = [
            AgentCallWorkflowStage(
                id: "context-collect",
                detail: "Capturing job scope and caller constraints.",
                phaseTitle: "Intake",
                elapsedSeconds: 18,
                participants: [roles.plannerActive, roles.callerStandby, roles.ownerStandby, roles.providerStandby],
                timeline: timelineBase,
                transcriptLines: [
                    .line(id: "l1", speaker: "Planner Agent", text: "I parsed your request: \(requestPrompt)", latency: 88),
                    .line(id: "l2", speaker: "Planner Agent", text: "Drafting checklist: address, budget, timing, and authorization.", latency: 94),
                ],
                steeringChoices: steeringChoices,
                suggestedSteeringID: "budget-cap",
                traceMessage: "context captured",
                renderDelayMs: 430
            ),
            AgentCallWorkflowStage(
                id: "context-questions",
                detail: "Preparing confirmation prompts before dialing.",
                phaseTitle: "Intake",
                elapsedSeconds: 46,
                participants: [roles.plannerActive, roles.callerStandby, roles.ownerStandby, roles.providerStandby],
                timeline: timelineBase,
                transcriptLines: [
                    .line(id: "l3", speaker: "Planner Agent", text: "Question ready: confirm service address and preferred arrival window.", latency: 112),
                    .translated(
                        id: "l4",
                        speaker: "Owner",
                        text: "Confirmed in Korean: same home address, morning preferred.",
                        originalText: "네, 같은 집 주소이고 오전이 좋아요.",
                        sourceLanguage: "ko",
                        targetLanguage: "en",
                        latency: 166
                    ),
                ],
                steeringChoices: steeringChoices,
                suggestedSteeringID: "budget-cap",
                traceMessage: "authorization questions generated",
                renderDelayMs: 460
            ),
            AgentCallWorkflowStage(
                id: "discovery",
                detail: "Building a provider shortlist and routing order.",
                phaseTitle: "Discovery",
                elapsedSeconds: 82,
                participants: [roles.plannerActive, roles.callerActive, roles.ownerStandby, roles.providerStandby],
                timeline: timelineBase,
                transcriptLines: [
                    .line(id: "l5", speaker: "Caller Agent", text: "Provider list ready: GreenEdge, RapidLawn, Sunrise Yard.", latency: 211),
                    .line(id: "l6", speaker: "Planner Agent", text: "Routing by rating + distance; first dial is GreenEdge.", latency: 205),
                ],
                steeringChoices: steeringChoices,
                suggestedSteeringID: "confirm-license",
                traceMessage: "provider shortlist complete",
                renderDelayMs: 440
            ),
            AgentCallWorkflowStage(
                id: "dialing",
                detail: "Dialing first provider and introducing case context.",
                phaseTitle: "Call in progress",
                elapsedSeconds: 128,
                participants: [roles.plannerActive, roles.callerActive, roles.ownerJoined, roles.providerJoined],
                timeline: timelineBase,
                transcriptLines: [
                    .line(id: "l7", speaker: "Caller Agent", text: "Connected to GreenEdge dispatch. Negotiation started.", latency: 372),
                    .line(id: "l8", speaker: "GreenEdge Dispatch", text: "Base quote is $105. Earliest slot is tomorrow 9–11 AM.", latency: 521),
                    .line(id: "l9", speaker: "Owner", text: "I joined to authorize DOB verification only.", latency: 156),
                ],
                steeringChoices: steeringChoices,
                suggestedSteeringID: "budget-cap",
                traceMessage: "first provider connected",
                renderDelayMs: 500
            ),
            AgentCallWorkflowStage(
                id: "authorization",
                detail: "Owner authorizes identity details, then exits call.",
                phaseTitle: "Call in progress",
                elapsedSeconds: 174,
                participants: [roles.plannerActive, roles.callerActive, roles.ownerLeft, roles.providerJoined],
                timeline: timelineBase,
                transcriptLines: [
                    .line(id: "l10", speaker: "Owner", text: "DOB provided and confirmed. I am leaving the call now.", latency: 147),
                    .line(id: "l11", speaker: "Caller Agent", text: "Owner dropped. Continuing negotiation autonomously.", latency: 201),
                ],
                steeringChoices: steeringChoices,
                suggestedSteeringID: "expedite",
                traceMessage: "owner joined and left cleanly",
                renderDelayMs: 460
            ),
            AgentCallWorkflowStage(
                id: "negotiation",
                detail: "Negotiating budget and service inclusions.",
                phaseTitle: "Call in progress",
                elapsedSeconds: 222,
                participants: [roles.plannerActive, roles.callerActive, roles.ownerLeft, roles.providerJoined],
                timeline: timelineBase,
                transcriptLines: [
                    .line(id: "l12", speaker: "Caller Agent", text: "Requested a discount under $95 with same-day confirmation.", latency: 318),
                    .line(id: "l13", speaker: "GreenEdge Dispatch", text: "Updated quote: $85 with confirmation text included.", latency: 498),
                ],
                steeringChoices: steeringChoices,
                suggestedSteeringID: "confirm-license",
                traceMessage: "quote negotiated to target",
                renderDelayMs: 450
            ),
            AgentCallWorkflowStage(
                id: "secondary-calls",
                detail: "Running secondary calls for benchmark pricing.",
                phaseTitle: "Benchmarking",
                elapsedSeconds: 276,
                participants: [roles.plannerActive, roles.callerActive, roles.ownerStandby, roles.providerStandby],
                timeline: timelineBase,
                transcriptLines: [
                    .line(id: "l14", speaker: "Caller Agent", text: "RapidLawn quote: $95, arrival 1–3 PM.", latency: 452),
                    .line(id: "l15", speaker: "Caller Agent", text: "Sunrise quote: $110, arrival 8–10 AM.", latency: 477),
                ],
                steeringChoices: steeringChoices,
                suggestedSteeringID: "budget-cap",
                traceMessage: "secondary quotes completed",
                renderDelayMs: 450
            ),
            AgentCallWorkflowStage(
                id: "qa",
                detail: "Verifying policy constraints and final recommendation.",
                phaseTitle: "Final QA",
                elapsedSeconds: 301,
                participants: [roles.plannerActive, roles.callerActive, roles.ownerStandby, roles.providerStandby],
                timeline: timelineBase,
                transcriptLines: [
                    .line(id: "l16", speaker: "Planner Agent", text: "Cross-check complete: GreenEdge meets budget, timing, and proof-of-insurance requirements.", latency: 241),
                    .line(id: "l17", speaker: "Planner Agent", text: "Packaging ranked offers and preparing user decision card.", latency: 189),
                ],
                steeringChoices: steeringChoices,
                suggestedSteeringID: "budget-cap",
                traceMessage: "recommendation finalized",
                renderDelayMs: 380
            ),
        ]

        let offers: [AgentCallOffer] = [
            AgentCallOffer(
                id: "greenedge",
                providerName: "GreenEdge Landscaping",
                phoneNumber: "(951) 555-0181",
                priceText: "$85",
                availabilityText: "Tomorrow 9:00–11:00 AM",
                weatherSummary: "Clear, 74°F",
                mapSummary: "18 min away",
                notes: "Negotiated down from $105 after budget-cap steer. Includes text confirmation."
            ),
            AgentCallOffer(
                id: "rapidlawn",
                providerName: "RapidLawn Services",
                phoneNumber: "(951) 555-0133",
                priceText: "$95",
                availabilityText: "Tomorrow 1:00–3:00 PM",
                weatherSummary: "Partly cloudy, 72°F",
                mapSummary: "12 min away",
                notes: "Second-best price and fastest route, later time window."
            ),
            AgentCallOffer(
                id: "sunrise",
                providerName: "Sunrise Yard Care",
                phoneNumber: "(951) 555-0199",
                priceText: "$110",
                availabilityText: "Tomorrow 8:00–10:00 AM",
                weatherSummary: "Sunny, 75°F",
                mapSummary: "26 min away",
                notes: "Highest quote, earliest start, not budget aligned."
            ),
        ]

        let metrics: [AgentWorkflowMetric] = [
            AgentWorkflowMetric(id: "duration", title: "Virtual call span", value: "05:01", detail: "Accelerated playback in app"),
            AgentWorkflowMetric(id: "avg-latency", title: "Avg transcript latency", value: "292 ms", detail: "Speaker-tagged turn processing"),
            AgentWorkflowMetric(id: "p95-latency", title: "P95 transcript latency", value: "521 ms", detail: "Worst turn under one second"),
            AgentWorkflowMetric(id: "handoffs", title: "Agent handoffs", value: "3", detail: "Planner -> Caller -> Planner"),
        ]

        let highlights = [
            "Owner joined for DOB authorization, then left while the call continued.",
            "Budget-cap steering was honored before final quote acceptance.",
            "All offers include provider, price, and availability for one-tap selection.",
        ]

        return AgentCallWorkflowScenario(
            id: "scenario-\(UUID().uuidString)",
            prompt: requestPrompt,
            stages: stages,
            offers: offers,
            recommendedOfferID: offers.first?.id,
            highlights: highlights,
            metrics: metrics
        )
    }

    func reportText(traceTag: String, selectedOfferID: String?) -> String {
        let selectedLabel: String
        if let selectedOfferID,
           let selected = offers.first(where: { $0.id == selectedOfferID }) {
            selectedLabel = "\(selected.providerName) \(selected.priceText) \(selected.availabilityText)"
        } else {
            selectedLabel = "No final provider selected"
        }

        let metricLines = metrics
            .map { "- \($0.title): \($0.value)\($0.detail.map { " (\($0))" } ?? "")" }
            .joined(separator: "\n")

        let highlightLines = highlights.map { "- \($0)" }.joined(separator: "\n")

        return """
        Rotary Agent Call Report
        Trace: \(traceTag)
        Prompt: \(prompt)
        Selected: \(selectedLabel)

        Highlights
        \(highlightLines)

        Metrics
        \(metricLines)
        """
    }
}

private struct ParticipantRoles {
    let plannerActive = AgentWorkflowParticipant(id: "planner", name: "Planner Agent", role: "Acting", state: .active)
    let callerStandby = AgentWorkflowParticipant(id: "caller", name: "Caller Agent", role: "Execution", state: .standby)
    let callerActive = AgentWorkflowParticipant(id: "caller", name: "Caller Agent", role: "Execution", state: .active)
    let ownerStandby = AgentWorkflowParticipant(id: "owner", name: "Owner", role: "Authorization", state: .standby)
    let ownerJoined = AgentWorkflowParticipant(id: "owner", name: "Owner", role: "Authorization", state: .active)
    let ownerLeft = AgentWorkflowParticipant(id: "owner", name: "Owner", role: "Authorization", state: .left)
    let providerStandby = AgentWorkflowParticipant(id: "provider", name: "Provider", role: "External", state: .standby)
    let providerJoined = AgentWorkflowParticipant(id: "provider", name: "Provider", role: "External", state: .active)
}

private extension AgentWorkflowTranscriptLine {
    static func line(id: String, speaker: String, text: String, latency: Int) -> AgentWorkflowTranscriptLine {
        AgentWorkflowTranscriptLine(
            id: id,
            speaker: speaker,
            text: text,
            latencyMs: latency,
            isTranslated: false,
            originalText: nil,
            sourceLanguage: nil,
            targetLanguage: nil
        )
    }

    static func translated(
        id: String,
        speaker: String,
        text: String,
        originalText: String,
        sourceLanguage: String,
        targetLanguage: String,
        latency: Int
    ) -> AgentWorkflowTranscriptLine {
        AgentWorkflowTranscriptLine(
            id: id,
            speaker: speaker,
            text: text,
            latencyMs: latency,
            isTranslated: true,
            originalText: originalText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
    }
}
