import XCTest
@testable import Rotary

final class AgentCallWorkflowScenarioTests: XCTestCase {
    func testScenarioContainsDeterministicStagesAndParticipants() {
        let scenario = AgentCallWorkflowScenario.build(prompt: "Call lawn providers and negotiate")

        XCTAssertEqual(scenario.stages.count, 8)
        XCTAssertEqual(scenario.offers.count, 3)
        XCTAssertEqual(scenario.recommendedOfferID, "greenedge")

        let hasOwnerJoin = scenario.stages.contains { stage in
            stage.participants.contains { $0.id == "owner" && $0.state == .active }
        }
        let hasOwnerLeave = scenario.stages.contains { stage in
            stage.participants.contains { $0.id == "owner" && $0.state == .left }
        }

        XCTAssertTrue(hasOwnerJoin)
        XCTAssertTrue(hasOwnerLeave)
    }

    func testScenarioIncludesTranslatedTranscriptLine() {
        let scenario = AgentCallWorkflowScenario.build(prompt: "Handle insurance call")
        let transcript = scenario.stages.flatMap(\.transcriptLines)

        let translated = transcript.first { $0.isTranslated }
        XCTAssertNotNil(translated)
        XCTAssertEqual(translated?.sourceLanguage, "ko")
        XCTAssertEqual(translated?.targetLanguage, "en")
        XCTAssertNotNil(translated?.originalText)
    }

    func testReportTextIncludesTraceAndMetrics() {
        let scenario = AgentCallWorkflowScenario.build(prompt: "Book interpreter")
        let report = scenario.reportText(traceTag: "trace-123", selectedOfferID: "greenedge")

        XCTAssertTrue(report.contains("Trace: trace-123"))
        XCTAssertTrue(report.contains("Metrics"))
        XCTAssertTrue(report.contains("Virtual call span"))
        XCTAssertTrue(report.contains("GreenEdge Landscaping"))
    }
}
