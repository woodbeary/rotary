import XCTest
@testable import Rotary

final class RotaryDeepLinkTests: XCTestCase {
    func testParsesMessageThreadDeepLink() {
        let url = URL(string: "rotary://messages/thread_123")!
        XCTAssertEqual(RotaryDeepLink.parse(url), .messagesThread(threadID: "thread_123"))
    }

    func testParsesAgentConversationDeepLinkFromQuery() {
        let url = URL(string: "rotary://agents?agentId=agent_456")!
        XCTAssertEqual(RotaryDeepLink.parse(url), .agentConversation(agentID: "agent_456"))
    }

    func testParsesCallsLiveAssistDeepLink() {
        let url = URL(string: "rotary://calls/live-assist/call_789")!
        XCTAssertEqual(RotaryDeepLink.parse(url), .callsLiveAssist(callID: "call_789"))
    }

    func testParsesSettingsDeepLink() {
        let url = URL(string: "rotary://settings")!
        XCTAssertEqual(RotaryDeepLink.parse(url), .settings)
    }

    func testIgnoresAuthCallbackDeepLink() {
        let url = URL(string: "rotary://auth?ticket=abc")!
        XCTAssertNil(RotaryDeepLink.parse(url))
    }
}
