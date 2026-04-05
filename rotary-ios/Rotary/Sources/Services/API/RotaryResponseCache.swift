import Foundation

actor RotaryResponseCache {
    private struct Entry: Codable {
        let data: Data
        let expiresAt: Date
    }

    private var entries: [String: Entry] = [:]
    private let fileURL: URL
    private var hasLoadedFromDisk = false

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            self.fileURL = (cachesDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory()))
                .appendingPathComponent("rotary-response-cache.json", conformingTo: .json)
        }
    }

    func data(for key: String, now: Date = Date()) -> Data? {
        loadFromDiskIfNeeded()
        trimExpiredEntries(now: now)
        guard let entry = entries[key] else { return nil }
        return entry.data
    }

    func store(_ data: Data, for key: String, ttl: TimeInterval, now: Date = Date()) {
        loadFromDiskIfNeeded()
        entries[key] = Entry(data: data, expiresAt: now.addingTimeInterval(ttl))
        persistEntries()
    }

    func invalidate(prefixes: [String]) {
        loadFromDiskIfNeeded()
        guard !prefixes.isEmpty else { return }
        entries = entries.filter { key, _ in
            !prefixes.contains(where: { key.hasPrefix($0) })
        }
        persistEntries()
    }

    func removeAll() {
        loadFromDiskIfNeeded()
        entries.removeAll(keepingCapacity: false)
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func loadFromDiskIfNeeded() {
        guard !hasLoadedFromDisk else { return }
        hasLoadedFromDisk = true

        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        entries = decoded
    }

    private func trimExpiredEntries(now: Date) {
        let originalCount = entries.count
        entries = entries.filter { _, entry in
            entry.expiresAt > now
        }
        guard entries.count != originalCount else { return }
        persistEntries()
    }

    private func persistEntries() {
        let fileManager = FileManager.default
        if entries.isEmpty {
            try? fileManager.removeItem(at: fileURL)
            return
        }

        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Failed to persist RotaryResponseCache: \(error)")
        }
    }
}
