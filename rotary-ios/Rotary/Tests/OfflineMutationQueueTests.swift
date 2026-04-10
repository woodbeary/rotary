import XCTest
@testable import Rotary

final class OfflineMutationQueueTests: XCTestCase {
    func testQueuePersistsRecordsAcrossInstances() async {
        let fileURL = temporaryFileURL()
        let queue = OfflineMutationQueue(fileURL: fileURL)

        _ = await queue.enqueue(
            payload: .sendMessage(
                SendMessageMutationPayload(
                    contactId: "contact-1",
                    toNumber: nil,
                    fromNumber: "+15555550100",
                    message: "Hello"
                )
            ),
            now: Date(timeIntervalSince1970: 10)
        )

        let secondQueue = OfflineMutationQueue(fileURL: fileURL)
        let records = await secondQueue.allRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.payload.kind, .sendMessage)

        await secondQueue.removeAll()
    }

    func testQueueBackoffAndRetryReset() async {
        let fileURL = temporaryFileURL()
        let queue = OfflineMutationQueue(fileURL: fileURL)
        let now = Date(timeIntervalSince1970: 1_000)

        let record = await queue.enqueue(
            payload: .createWorkspace(CreateWorkspaceMutationPayload(businessName: "Rotary")),
            now: now
        )

        await queue.markFailed(id: record.id, reason: "offline", now: now)
        let failed = await queue.failedRecords()

        XCTAssertEqual(failed.count, 1)
        XCTAssertEqual(failed.first?.attempts, 1)
        XCTAssertEqual(failed.first?.status, .failed)
        XCTAssertNotNil(failed.first?.nextRetryAt)

        await queue.markFailedAsPending()
        let due = await queue.dueRecords(now: now)
        XCTAssertEqual(due.count, 1)
        XCTAssertEqual(due.first?.status, .pending)

        await queue.removeAll()
    }

    func testTempIDMappingResolvesToServerID() async {
        let fileURL = temporaryFileURL()
        let queue = OfflineMutationQueue(fileURL: fileURL)

        await queue.setTempIDMapping(tempID: "temp-agent:1", serverID: "agent-1")
        let resolved = await queue.resolveID("temp-agent:1")
        XCTAssertEqual(resolved, "agent-1")

        await queue.removeAll()
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("rotary-offline-test-\(UUID().uuidString).json")
    }
}
