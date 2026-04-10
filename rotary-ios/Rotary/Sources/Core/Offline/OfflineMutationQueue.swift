import Foundation

actor OfflineMutationQueue {
    private struct PersistedState: Codable {
        var records: [OfflineMutationRecord]
        var tempIDRemap: [String: String]
        var lastSuccessfulSyncAt: Date?
    }

    private var records: [OfflineMutationRecord] = []
    private var tempIDRemap: [String: String] = [:]
    private var lastSuccessfulSyncAt: Date?

    private let fileURL: URL
    private var hasLoadedFromDisk = false

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            self.fileURL = (appSupportDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory()))
                .appendingPathComponent("rotary-offline-mutations.json", conformingTo: .json)
        }
    }

    @discardableResult
    func enqueue(payload: OfflineMutationPayload, now: Date = Date()) -> OfflineMutationRecord {
        loadFromDiskIfNeeded()

        let record = OfflineMutationRecord(
            id: UUID().uuidString,
            payload: payload,
            createdAt: now,
            status: .pending,
            attempts: 0,
            nextRetryAt: nil,
            lastAttemptAt: nil,
            failureReason: nil
        )
        records.append(record)
        persist()
        return record
    }

    func dueRecords(now: Date = Date()) -> [OfflineMutationRecord] {
        loadFromDiskIfNeeded()
        return records
            .filter { record in
                switch record.status {
                case .pending:
                    return record.nextRetryAt == nil || (record.nextRetryAt ?? .distantPast) <= now
                case .failed:
                    return record.nextRetryAt == nil || (record.nextRetryAt ?? .distantPast) <= now
                case .executing:
                    return false
                }
            }
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id < rhs.id
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    func markExecuting(id: String, now: Date = Date()) {
        loadFromDiskIfNeeded()
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].status = .executing
        records[index].lastAttemptAt = now
        persist()
    }

    func markFailed(id: String, reason: String, now: Date = Date()) {
        loadFromDiskIfNeeded()
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }

        records[index].attempts += 1
        records[index].status = .failed
        records[index].failureReason = reason
        records[index].lastAttemptAt = now

        // Exponential backoff with an upper bound so the queue remains responsive.
        let backoffSeconds = min(pow(2.0, Double(records[index].attempts)) * 2.0, 300.0)
        records[index].nextRetryAt = now.addingTimeInterval(backoffSeconds)

        persist()
    }

    func markSucceeded(id: String, tempMapping: (tempID: String, serverID: String)? = nil, now: Date = Date()) {
        loadFromDiskIfNeeded()
        if let tempMapping {
            tempIDRemap[tempMapping.tempID] = tempMapping.serverID
        }
        records.removeAll { $0.id == id }
        lastSuccessfulSyncAt = now
        persist()
    }

    func markFailedAsPending() {
        loadFromDiskIfNeeded()
        for index in records.indices {
            if records[index].status == .failed {
                records[index].status = .pending
                records[index].nextRetryAt = nil
            }
        }
        persist()
    }

    func resolveID(_ maybeTempID: String?) -> String? {
        loadFromDiskIfNeeded()
        guard let maybeTempID else { return nil }
        return tempIDRemap[maybeTempID] ?? maybeTempID
    }

    func setTempIDMapping(tempID: String, serverID: String) {
        loadFromDiskIfNeeded()
        tempIDRemap[tempID] = serverID
        persist()
    }

    func currentSnapshot() -> OfflineQueueSnapshot {
        loadFromDiskIfNeeded()

        let pendingCount = records.filter { $0.status == .pending || $0.status == .executing }.count
        let failedRecords = records.filter { $0.status == .failed }
        let latestFailureReason = failedRecords
            .sorted { ($0.lastAttemptAt ?? $0.createdAt) > ($1.lastAttemptAt ?? $1.createdAt) }
            .first?
            .failureReason

        return OfflineQueueSnapshot(
            pendingCount: pendingCount,
            failedCount: failedRecords.count,
            totalCount: records.count,
            latestFailureReason: latestFailureReason,
            lastSuccessfulSyncAt: lastSuccessfulSyncAt
        )
    }

    func failedRecords() -> [OfflineMutationRecord] {
        loadFromDiskIfNeeded()
        return records
            .filter { $0.status == .failed }
            .sorted { ($0.lastAttemptAt ?? $0.createdAt) > ($1.lastAttemptAt ?? $1.createdAt) }
    }

    func allRecords() -> [OfflineMutationRecord] {
        loadFromDiskIfNeeded()
        return records
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id < rhs.id
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    func removeAll() {
        loadFromDiskIfNeeded()
        records.removeAll(keepingCapacity: false)
        tempIDRemap.removeAll(keepingCapacity: false)
        lastSuccessfulSyncAt = nil
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func loadFromDiskIfNeeded() {
        guard !hasLoadedFromDisk else { return }
        hasLoadedFromDisk = true

        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let decoded = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }

        records = decoded.records
        tempIDRemap = decoded.tempIDRemap
        lastSuccessfulSyncAt = decoded.lastSuccessfulSyncAt
    }

    private func persist() {
        let fileManager = FileManager.default

        if records.isEmpty, tempIDRemap.isEmpty, lastSuccessfulSyncAt == nil {
            try? fileManager.removeItem(at: fileURL)
            return
        }

        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let state = PersistedState(
                records: records,
                tempIDRemap: tempIDRemap,
                lastSuccessfulSyncAt: lastSuccessfulSyncAt
            )
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Failed to persist OfflineMutationQueue: \(error)")
        }
    }
}
