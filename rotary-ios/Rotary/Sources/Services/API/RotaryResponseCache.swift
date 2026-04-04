import Foundation

actor RotaryResponseCache {
    private struct Entry {
        let data: Data
        let expiresAt: Date
    }

    private var entries: [String: Entry] = [:]

    func data(for key: String, now: Date = Date()) -> Data? {
        guard let entry = entries[key] else { return nil }
        guard entry.expiresAt > now else {
            entries.removeValue(forKey: key)
            return nil
        }
        return entry.data
    }

    func store(_ data: Data, for key: String, ttl: TimeInterval, now: Date = Date()) {
        entries[key] = Entry(data: data, expiresAt: now.addingTimeInterval(ttl))
    }

    func invalidate(prefixes: [String]) {
        guard !prefixes.isEmpty else { return }
        entries = entries.filter { key, _ in
            !prefixes.contains(where: { key.hasPrefix($0) })
        }
    }

    func removeAll() {
        entries.removeAll(keepingCapacity: false)
    }
}
