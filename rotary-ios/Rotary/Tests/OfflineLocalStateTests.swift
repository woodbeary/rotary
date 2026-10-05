import XCTest
@testable import Rotary

final class OfflineLocalStateTests: XCTestCase {
    @MainActor
    func testInferenceModeStorePersistsSelectedMode() {
        let suiteName = "rotary.inference-mode.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = InferenceModeStore(defaults: defaults)
        XCTAssertEqual(store.mode, .cloud)

        store.mode = .local

        let reloaded = InferenceModeStore(defaults: defaults)
        XCTAssertEqual(reloaded.mode, .local)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testLocalConversationStorePersistsMessagesByAgent() async {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rotary-local-conversation-test-\(UUID().uuidString).json")

        let message = MobileAgentConversationMessage(
            id: "message-1",
            role: "user",
            content: "hello",
            originalContent: nil,
            sourceLanguage: nil,
            targetLanguage: nil,
            wasTranslated: nil,
            deliveryStatus: nil,
            provider: nil,
            thinkingMode: "balanced",
            messageKind: "text",
            createdAt: "2026-01-01T00:00:00Z",
            attachments: []
        )

        let firstStore = LocalConversationStore(fileURL: fileURL)
        await firstStore.replaceMessages([message], for: "agent-1")

        let secondStore = LocalConversationStore(fileURL: fileURL)
        let loaded = await secondStore.messages(for: "agent-1")
        XCTAssertEqual(loaded, [message])

        await secondStore.clear(agentID: "agent-1")
    }
}
