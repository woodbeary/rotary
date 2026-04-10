import Foundation

actor LocalConversationStore {
    private struct PersistedState: Codable {
        var messagesByAgentID: [String: [MobileAgentConversationMessage]]
    }

    static let shared = LocalConversationStore()

    private var messagesByAgentID: [String: [MobileAgentConversationMessage]] = [:]
    private let fileURL: URL
    private var hasLoadedFromDisk = false

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            self.fileURL = (appSupportDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory()))
                .appendingPathComponent("rotary-local-conversations.json", conformingTo: .json)
        }
    }

    func messages(for agentID: String) -> [MobileAgentConversationMessage] {
        loadIfNeeded()
        return messagesByAgentID[agentID] ?? []
    }

    func replaceMessages(_ messages: [MobileAgentConversationMessage], for agentID: String) {
        loadIfNeeded()
        messagesByAgentID[agentID] = messages
        persist()
    }

    func appendMessage(_ message: MobileAgentConversationMessage, for agentID: String) {
        loadIfNeeded()
        messagesByAgentID[agentID, default: []].append(message)
        persist()
    }

    func clear(agentID: String) {
        loadIfNeeded()
        messagesByAgentID.removeValue(forKey: agentID)
        persist()
    }

    private func loadIfNeeded() {
        guard !hasLoadedFromDisk else { return }
        hasLoadedFromDisk = true

        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let decoded = try? JSONDecoder.rotary.decode(PersistedState.self, from: data) else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        messagesByAgentID = decoded.messagesByAgentID
    }

    private func persist() {
        let fileManager = FileManager.default
        if messagesByAgentID.isEmpty {
            try? fileManager.removeItem(at: fileURL)
            return
        }

        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let data = try JSONEncoder().encode(
                PersistedState(messagesByAgentID: messagesByAgentID)
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Failed to persist LocalConversationStore: \(error)")
        }
    }
}
