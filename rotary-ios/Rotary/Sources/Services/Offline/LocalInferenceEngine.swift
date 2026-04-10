import Foundation
import Observation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct LocalModelDescriptor: Hashable, Codable, Identifiable {
    let id: String
    let displayName: String
    let storageFootprint: String
}

enum LocalModelCatalog {
    static let appleFoundation = LocalModelDescriptor(
        id: "apple-foundation-general",
        displayName: "Apple On-Device Foundation Model",
        storageFootprint: "Managed by iOS"
    )

    static let all: [LocalModelDescriptor] = [appleFoundation]
}

enum LocalInferenceStatus: Equatable {
    case idle
    case loading
    case ready(modelID: String)
    case unavailable(reason: String)
    case failed(reason: String)
}

extension LocalInferenceStatus {
    var detailText: String {
        switch self {
        case .idle:
            return "Apple manages offline model availability and any required downloads for this iPhone."
        case .loading:
            return "Preparing the on-device assistant."
        case let .ready(modelID):
            return "Rotary can answer with \(modelID) on this iPhone."
        case let .unavailable(reason), let .failed(reason):
            return reason
        }
    }
}

struct LocalInferenceAttachment: Hashable {
    let fileName: String
    let kind: String
    let extractedText: String?
}

struct LocalInferenceTurn: Hashable {
    let role: String
    let content: String
}

struct LocalInferenceInput: Hashable {
    let prompt: String
    let thinkingMode: String
    let attachments: [LocalInferenceAttachment]
    let isRealtimeSession: Bool
    let conversationHistory: [LocalInferenceTurn]
}

struct LocalInferenceOutput: Hashable {
    let text: String
    let modelID: String
    let createdAt: String
}

@MainActor
protocol LocalInferenceServing: AnyObject {
    var status: LocalInferenceStatus { get }
    func warmupIfNeeded() async
    func refreshAvailability() async
    func generate(input: LocalInferenceInput) async throws -> LocalInferenceOutput
}

@MainActor
@Observable
final class LocalModelManager {
    static let shared = LocalModelManager()

    private(set) var status: LocalInferenceStatus = .idle
    private(set) var activeModel: LocalModelDescriptor?

    var isSupportedDevice: Bool {
        Self.supportsFoundationRuntime
    }

    var isReadyForExecution: Bool {
        if case .ready = status {
            return true
        }
        return false
    }

    var statusTitle: String {
        switch status {
        case .idle:
            return isSupportedDevice ? "Ready to prepare" : "Unavailable"
        case .loading:
            return "Preparing"
        case .ready:
            return "Ready on this iPhone"
        case .unavailable:
            return "Unavailable"
        case .failed:
            return "Needs attention"
        }
    }

    var storageFootprint: String {
        activeModel?.storageFootprint ?? LocalModelCatalog.appleFoundation.storageFootprint
    }

    func refreshAvailability() async {
        guard Self.supportsFoundationRuntime else {
            activeModel = nil
            status = .unavailable(reason: Self.unsupportedRuntimeMessage)
            return
        }

        do {
            let descriptor = try Self.resolveRuntimeDescriptor()
            activeModel = descriptor
            if isReadyForExecution {
                return
            }
            status = .idle
        } catch let error as LocalInferenceError {
            activeModel = nil
            status = Self.status(for: error)
        } catch {
            activeModel = nil
            status = .failed(reason: error.localizedDescription)
        }
    }

    func warmupIfNeeded() async {
        guard !isReadyForExecution else { return }
        await warmup()
    }

    func warmup() async {
        guard Self.supportsFoundationRuntime else {
            activeModel = nil
            status = .unavailable(reason: Self.unsupportedRuntimeMessage)
            return
        }

        if case .loading = status {
            return
        }

        status = .loading

        do {
            let descriptor = try Self.resolveRuntimeDescriptor()
            try await Self.prewarmRuntime()
            activeModel = descriptor
            status = .ready(modelID: descriptor.id)
        } catch let error as LocalInferenceError {
            activeModel = nil
            status = Self.status(for: error)
        } catch {
            activeModel = nil
            status = .failed(reason: error.localizedDescription)
        }
    }

    func unload() {
        activeModel = nil
        status = .idle
    }

    fileprivate static var systemInstructions: String {
        """
        You are Rotary's on-device assistant.
        Reply in plain text only.
        Keep answers concise, calm, and actionable.
        Never emit markdown headings, code fences, or signoff markers.
        If you are missing key context, ask one short follow-up question instead of guessing.
        """
    }

    private static var supportsFoundationRuntime: Bool {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return true
        }
#endif
        return false
    }

    private static var unsupportedRuntimeMessage: String {
        "Offline assistant needs iOS 26 and Apple Intelligence support. Rotary will stay on cloud on this iPhone."
    }

    private static func status(for error: LocalInferenceError) -> LocalInferenceStatus {
        switch error {
        case let .unavailable(reason):
            return .unavailable(reason: reason)
        case let .failed(reason):
            return .failed(reason: reason)
        case .loading:
            return .loading
        }
    }

    private static func resolveRuntimeDescriptor() throws -> LocalModelDescriptor {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return LocalModelCatalog.appleFoundation
            case let .unavailable(reason):
                throw LocalInferenceError.unavailable(unavailableMessage(for: reason))
            }
        }
#endif
        throw LocalInferenceError.unavailable(unsupportedRuntimeMessage)
    }

    private static func prewarmRuntime() async throws {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                let session = LanguageModelSession(
                    model: .default,
                    instructions: systemInstructions
                )
                session.prewarm()
                return
            case let .unavailable(reason):
                throw LocalInferenceError.unavailable(unavailableMessage(for: reason))
            }
        }
#endif
        throw LocalInferenceError.unavailable(unsupportedRuntimeMessage)
    }

#if canImport(FoundationModels)
    @available(iOS 26.0, *)
    fileprivate static func unavailableMessage(
        for reason: SystemLanguageModel.Availability.UnavailableReason
    ) -> String {
        switch reason {
        case .deviceNotEligible:
            return "Offline assistant needs newer Apple Intelligence hardware. Rotary will stay on cloud on this iPhone."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is turned off. Enable it in iPhone Settings to use Rotary offline."
        case .modelNotReady:
            return "The on-device model is still preparing. Leave Apple Intelligence enabled and try again in a moment."
        @unknown default:
            return "Rotary could not confirm on-device model availability on this iPhone."
        }
    }
#endif
}

@MainActor
@Observable
final class LocalInferenceEngine: LocalInferenceServing {
    static let shared = LocalInferenceEngine(modelManager: .shared)

    private let modelManager: LocalModelManager

    init(modelManager: LocalModelManager) {
        self.modelManager = modelManager
    }

    var status: LocalInferenceStatus {
        modelManager.status
    }

    var canExecuteLocally: Bool {
        modelManager.isReadyForExecution
    }

    var fallbackMessage: String {
        status.detailText
    }

    func warmupIfNeeded() async {
        await modelManager.warmupIfNeeded()
    }

    func refreshAvailability() async {
        await modelManager.refreshAvailability()
    }

    func generate(input: LocalInferenceInput) async throws -> LocalInferenceOutput {
        await modelManager.warmupIfNeeded()

        guard case .ready(let modelID) = modelManager.status else {
            switch modelManager.status {
            case .unavailable(let reason):
                throw LocalInferenceError.unavailable(reason)
            case .failed(let reason):
                throw LocalInferenceError.failed(reason)
            case .loading:
                throw LocalInferenceError.loading
            case .idle:
                throw LocalInferenceError.failed("Offline assistant is not ready yet.")
            case .ready:
                throw LocalInferenceError.failed("Offline assistant status mismatch.")
            }
        }

        let responseText = try await generateReply(input: input)

        return LocalInferenceOutput(
            text: rotarySanitizedConversationText(responseText),
            modelID: modelID,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    private func generateReply(input: LocalInferenceInput) async throws -> String {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                let session = LanguageModelSession(
                    model: .default,
                    instructions: LocalModelManager.systemInstructions
                )
                let response = try await session.respond(to: promptText(for: input))
                return response.content
            case let .unavailable(reason):
                throw LocalInferenceError.unavailable(LocalModelManager.unavailableMessage(for: reason))
            }
        }
#endif
        throw LocalInferenceError.unavailable("Offline assistant is not available on this iPhone.")
    }

    private func promptText(for input: LocalInferenceInput) -> String {
        var sections: [String] = []

        let trimmedPrompt = input.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedThinkingMode = input.thinkingMode.trimmingCharacters(in: .whitespacesAndNewlines)
        sections.append("Thinking mode: \(normalizedThinkingMode.isEmpty ? "balanced" : normalizedThinkingMode)")

        if input.isRealtimeSession {
            sections.append("The user is speaking in real time. Reply naturally and keep the answer tight.")
        }

        let history = conversationHistoryText(input.conversationHistory)
        if !history.isEmpty {
            sections.append("Recent conversation:\n\(history)")
        }

        let attachmentContext = attachmentContextText(input.attachments)
        if !attachmentContext.isEmpty {
            sections.append("Attachment context:\n\(attachmentContext)")
        }

        sections.append(
            "Latest user request:\n\(trimmedPrompt.isEmpty ? "Please continue helping based on the conversation context." : trimmedPrompt)"
        )

        return sections.joined(separator: "\n\n")
    }

    private func conversationHistoryText(_ history: [LocalInferenceTurn]) -> String {
        guard !history.isEmpty else { return "" }

        return history.suffix(8).compactMap { turn in
            let sanitized = rotarySanitizedConversationText(turn.content)
            guard !sanitized.isEmpty else { return nil }

            let normalizedRole = turn.role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let prefix: String
            switch normalizedRole {
            case "assistant":
                prefix = "Assistant"
            case "system":
                prefix = "System"
            default:
                prefix = "User"
            }

            return "\(prefix): \(truncated(sanitized, limit: 600))"
        }
        .joined(separator: "\n")
    }

    private func attachmentContextText(_ attachments: [LocalInferenceAttachment]) -> String {
        guard !attachments.isEmpty else { return "" }

        return attachments.prefix(3).map { attachment in
            let extracted = attachment.extractedText?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = extracted?.isEmpty == false
                ? truncated(extracted!, limit: 1200)
                : "No extracted text available."
            return "\(attachment.fileName) (\(attachment.kind)): \(summary)"
        }
        .joined(separator: "\n\n")
    }

    private func truncated(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}

enum LocalInferenceError: LocalizedError {
    case unavailable(String)
    case failed(String)
    case loading

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason):
            return reason
        case .failed(let reason):
            return reason
        case .loading:
            return "Offline assistant is still preparing."
        }
    }
}
