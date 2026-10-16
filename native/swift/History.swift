import Foundation
import CryptoKit

struct BalanceRecord: Codable, Equatable {
    let id: String
    let sourceID: String
    let mode: String
    let day: String
    let collected: Date
    let received: Date
    let origin: String
    let rules: String
    let x: Double
    let y: Double
    let sums: [String: Double]
    let counts: [String: Int]
    let sources: [String: String]
    var magnitude: Double { max(abs(x), abs(y)) }
    var direction: String {
        if magnitude < 0.01 { return "balanced" }
        return abs(y) >= abs(x) ? (y < 0 ? "obligations" : "resources") : (x < 0 ? "past" : "future")
    }
    static func source(_ address: String?) -> String {
        let key = address.flatMap { Свежесть.endpoint($0)?.absoluteString } ?? "local-calendar"
        return SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    static func make(_ day: День, sourceID: String, origin: String, now: Date = Date()) -> BalanceRecord? {
        guard day.живой, day.режим != .образец, let date = Свежесть.дата(day.собрано),
              date <= now.addingTimeInterval(300) else { return nil }
        return BalanceRecord(id: sourceID + "|" + day.режим.rawValue + "|" + String(date.timeIntervalSince1970),
            sourceID: sourceID, mode: day.режим.rawValue, day: day.дата, collected: date, received: now,
            origin: origin, rules: day.rulesVersion,
            x: day.x, y: day.y,
            sums: Dictionary(uniqueKeysWithValues: day.лучи.map { ($0.имя, $0.сумма) }),
            counts: Dictionary(uniqueKeysWithValues: day.лучи.map { ($0.имя, $0.штук) }),
            sources: Dictionary(uniqueKeysWithValues: day.источники.map { ($0.имя, $0.статус) }))
    }
}

/// Derived only from saved aggregates; never persisted as another observation.
struct HistoryComparison {
    let previous: BalanceRecord
    let selected: BalanceRecord
    var interval: TimeInterval { selected.collected.timeIntervalSince(previous.collected) }
    var comparable: Bool { previous.rules == selected.rules }
    var intervalText: String {
        let seconds = max(0, Int(interval.rounded()))
        return "\(seconds / 86400)d \(seconds / 3600 % 24)h \(seconds / 60 % 60)m \(seconds % 60)s"
    }
    func sumDelta(_ arm: String) -> Double? {
        guard comparable, let old = previous.sums[arm], let new = selected.sums[arm] else { return nil }
        return new - old
    }
    func countDelta(_ arm: String) -> Int? {
        guard comparable, let old = previous.counts[arm], let new = selected.counts[arm] else { return nil }
        return new - old
    }
    static func find(for selected: BalanceRecord, in records: [BalanceRecord]) -> HistoryComparison? {
        let earlier = records.filter {
            $0.sourceID == selected.sourceID && $0.mode == selected.mode && $0.collected < selected.collected
        }
        guard let previous = earlier.max(by: {
            $0.collected == $1.collected ? $0.id < $1.id : $0.collected < $1.collected
        }) else { return nil }
        return HistoryComparison(previous: previous, selected: selected)
    }
    static func connects(_ previous: BalanceRecord, _ next: BalanceRecord, calendar: Calendar = .current) -> Bool {
        let elapsed = next.collected.timeIntervalSince(previous.collected)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: previous.collected), to: calendar.startOfDay(for: next.collected)).day ?? Int.max
        return previous.sourceID == next.sourceID && previous.mode == next.mode && previous.rules == next.rules
            && elapsed > 0 && elapsed < 36 * 3600 && days <= 1
    }
}

final class BalanceHistory {
    struct File: Codable { let version: Int; let records: [BalanceRecord] }
    let url: URL
    private(set) var records: [BalanceRecord] = []
    private(set) var issue: String?
    private var writable = true
    init(url: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Krest/history-v1.json")) {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
                guard file.version == 1 else { throw CocoaError(.coderReadCorrupt) }
                records = file.records.sorted { $0.collected < $1.collected }
            } catch { issue = "History could not be read; original file preserved"; writable = false }
        }
    }
    @discardableResult func append(_ record: BalanceRecord) -> Bool {
        guard writable else { return false }
        guard !records.contains(where: { $0.id == record.id }) else { return false }
        var next = records; next.append(record); next.sort { $0.collected < $1.collected }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            try JSONEncoder().encode(File(version: 1, records: next)).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            records = next; issue = nil; return true
        } catch { issue = "History not saved: check disk access"; return false }
    }
    func points(sourceID: String, mode: String) -> [BalanceRecord] {
        records.filter { $0.sourceID == sourceID && $0.mode == mode }
    }
    static func archiveNames(_ data: Data) -> [String] {
        guard let text = String(data: data, encoding: .utf8),
              let regex = try? NSRegularExpression(pattern: "href=\"([0-9]{4}-[0-9]{2}-[0-9]{2}\\.json)\"") else { return [] }
        return Array(Set(regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range(at: 1), in: text).map { String(text[$0]) }
        })).sorted().suffix(366).map { $0 }
    }
}

/// Read the existing same-board daily archive. No scheduler, server writes or public storage.
final class HistorySync {
    private var busy = false
    private var lastSuccess: Date?
    func load(address: String, store: BalanceHistory, force: Bool = false, completion: @escaping (String) -> Void) {
        guard !busy else { return }
        if !force, let lastSuccess, Date().timeIntervalSince(lastSuccess) < 3600 { return }
        guard let endpoint = Свежесть.endpoint(address) else { completion("Invalid archive address"); return }
        let root = endpoint.deletingLastPathComponent().appendingPathComponent("история", isDirectory: true)
        busy = true; completion("Reading saved archive…")
        request(root) { [weak self] bytes in
            guard let self else { return }
            guard let bytes else { self.busy = false; completion("Archive unavailable · local snapshots retained"); return }
            let names = BalanceHistory.archiveNames(bytes)
            guard !names.isEmpty else { self.busy = false; completion("Archive list empty or unsupported · local snapshots retained"); return }
            let source = BalanceRecord.source(address)
            let today = DateFormatter(); today.dateFormat = "yyyy-MM-dd"
            let pending = names.filter { name in
                let day = String(name.prefix(10))
                return day == today.string(from: Date()) || !store.records.contains { $0.sourceID == source && $0.day == day && $0.origin == "архив борта" }
            }
            self.next(pending, index: 0, root: root, source: source, store: store, added: 0, failed: 0, completion: completion)
        }
    }
    private func next(_ names: [String], index: Int, root: URL, source: String, store: BalanceHistory, added: Int, failed: Int, completion: @escaping (String) -> Void) {
        guard index < names.count else {
            busy = false; if failed == 0 { lastSuccess = Date() }
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            completion(store.issue ?? "Archive checked \(f.string(from: Date())) · added \(added)" + (failed > 0 ? " · unread \(failed)" : "")); return
        }
        request(root.appendingPathComponent(names[index])) { [weak self] data in
            guard let self else { return }
            var count = added, errors = failed
            if let data, let day = День.разобрать(data, живой: true), day.дата == String(names[index].prefix(10)),
               let record = BalanceRecord.make(day, sourceID: source, origin: "архив борта") {
                if store.append(record) { count += 1 }
            } else { errors += 1 }
            self.next(names, index: index + 1, root: root, source: source, store: store, added: count, failed: errors, completion: completion)
        }
    }
    private func request(_ url: URL, completion: @escaping (Data?) -> Void) {
        var request = URLRequest(url: url); request.timeoutInterval = 8; request.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: request) { data, response, error in
            let valid = error == nil && (response as? HTTPURLResponse)?.statusCode == 200 && (data?.count ?? 0) < 10_000_000
            DispatchQueue.main.async { completion(valid ? data : nil) }
        }.resume()
    }
}
