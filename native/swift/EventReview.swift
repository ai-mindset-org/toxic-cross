import Foundation
import CryptoKit
import UserNotifications

struct EventReview: Codable, Equatable {
    let occurrence: String
    let start: Date
    let end: Date
    let recorded: Date
    let feeling: Int
    let energy: Int
    let reframe: String
    static let feelings = ["very unpleasant", "unpleasant", "neutral", "pleasant", "very pleasant"]
    static let energies = ["much lower", "lower", "unchanged", "higher", "much higher"]
    static func key(_ event: CalendarMoment) -> String {
        SHA256.hash(data: Data(event.id.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Explicit personal input. Event titles and source URLs never enter this file.
final class EventReviewStore {
    let url: URL
    private(set) var records: [EventReview] = []
    private(set) var issue: String?
    init(url: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Krest/check-ins-v1.json")) {
        self.url = url
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            records = try JSONDecoder().decode([EventReview].self, from: Data(contentsOf: url))
            guard records.allSatisfy({(-2...2).contains($0.feeling) && (-2...2).contains($0.energy) && $0.end > $0.start}) else {
                records = []; issue = "Check-in file is invalid; original preserved"; return
            }
        } catch { issue = "Check-in file could not be read; original preserved" }
    }
    func review(_ event: CalendarMoment) -> EventReview? { records.first { $0.occurrence == EventReview.key(event) } }
    @discardableResult func save(_ event: CalendarMoment, feeling: Int, energy: Int, reframe: String, now: Date = Date()) -> Bool {
        guard issue == nil, (-2...2).contains(feeling), (-2...2).contains(energy), event.end > event.start else { return false }
        let value = EventReview(occurrence: EventReview.key(event), start: event.start, end: event.end, recorded: now, feeling: feeling, energy: energy, reframe: String(reframe.prefix(280)))
        let next = ([value] + records.filter { $0.occurrence != value.occurrence }).sorted { $0.recorded > $1.recorded }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let data = try JSONEncoder().encode(Array(next.prefix(5000)))
            try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            records = next; return true
        } catch { return false }
    }
    func summary(on day: Date, calendar: Calendar = .current) -> (count: Int, feeling: Double, energy: Double)? {
        let values = records.filter { calendar.isDate($0.start, inSameDayAs: day) }
        guard !values.isEmpty else { return nil }
        return (values.count, Double(values.reduce(0) { $0 + $1.feeling }) / Double(values.count), Double(values.reduce(0) { $0 + $1.energy }) / Double(values.count))
    }
}

/// Pure policy: never replay an old day, a declined event or a stale reading.
struct EventNoticePolicy {
    private(set) var previous: Date?
    private(set) var seen = Set<String>()
    mutating func evaluate(_ frame: CalendarFrame, now: Date, enabled: Bool, reviewed: Set<String>) -> [CalendarMoment] {
        defer { previous = now }
        guard enabled, frame.fresh(at: now), let previous, now.timeIntervalSince(previous) < 300 else { return [] }
        return frame.events.filter { event in
            let key = EventReview.key(event)
            guard !event.allDay, !event.declined, event.end > previous, event.end <= now,
                  now.timeIntervalSince(event.end) <= 180, !seen.contains(key), !reviewed.contains(key) else { return false }
            seen.insert(key); return true
        }
    }
}

final class EventNotices: NSObject, UNUserNotificationCenterDelegate {
    private var policy = EventNoticePolicy()
    var openDay: (() -> Void)?
    static let enabledKey = "KrestCheckInReminders"
    private(set) var status = "Off · in-app highlights remain available"
    func setEnabled(_ enabled: Bool, completion: @escaping () -> Void) {
        guard enabled else {
            UserDefaults.standard.set(false, forKey: Self.enabledKey)
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            status = "Off · in-app highlights remain available"; completion(); return
        }
        let center = UNUserNotificationCenter.current(); center.delegate = self
        center.requestAuthorization(options: [.alert]) { [weak self] allowed, _ in
            DispatchQueue.main.async {
                UserDefaults.standard.set(allowed, forKey: Self.enabledKey)
                self?.policy=EventNoticePolicy()
                self?.status = allowed ? "On · at most one quiet check-in per day, 08:00–21:00" : "Permission unavailable · check macOS Notifications settings"
                completion()
            }
        }
    }
    func update(_ frame: CalendarFrame, reviews: EventReviewStore, now: Date = Date()) {
        let enabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        let events = policy.evaluate(frame, now: now, enabled: enabled, reviewed: Set(reviews.records.map(\.occurrence)))
        guard enabled else { return }
        let center = UNUserNotificationCenter.current(); center.delegate = self
        status = "On · at most one per day, 08:00–21:00; no event titles"
        let day=Calendar.current.startOfDay(for:now).timeIntervalSince1970
        guard (8..<21).contains(Calendar.current.component(.hour,from:now)),UserDefaults.standard.double(forKey:"KrestLastCheckInNoticeDay") != day else{return}
        for event in events.prefix(1) {
            let content = UNMutableNotificationContent()
            content.title = "A moment to check in"
            content.body = "An event just ended. How did it feel, and what happened to your energy?"
            content.categoryIdentifier = "KREST_CHECK_IN"
            center.add(UNNotificationRequest(identifier: "krest-check-in-" + EventReview.key(event), content: content, trigger: nil))
            UserDefaults.standard.set(day,forKey:"KrestLastCheckInNoticeDay")
        }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in self?.openDay?(); completionHandler() }
    }
}

/// Sends only when explicitly enabled for the user's already configured board.
enum CalendarBoardBridge {
    static let enabledKey = "KrestShareCalendarWithBoard"
    static func send(_ frame: CalendarFrame, address: String, completion: @escaping (String) -> Void) {
        guard frame.fresh(at: Date()), let start=frame.start, let end=frame.end, let fetched=frame.fetched,
              let endpoint = Свежесть.endpoint(address) else { completion("Calendar bridge: source stale or unavailable"); return }
        let events: [[String: Any]] = frame.events.map { event in
            ["id": EventReview.key(event), "title": event.title, "start": ISO8601DateFormatter().string(from: event.start), "end": ISO8601DateFormatter().string(from: event.end), "allDay": event.allDay, "owner_response": event.declined ? "declined" : "accepted"]
        }
        let payload: [String: Any] = ["schemaVersion": 1, "source": "krest-calendar-bridge", "fetchedAt": ISO8601DateFormatter().string(from: fetched), "rangeStart": ISO8601DateFormatter().string(from: start), "rangeEnd": ISO8601DateFormatter().string(from: end), "maxAgeSeconds":frame.maxAge,"events": events]
        var request = URLRequest(url: endpoint.deletingLastPathComponent().appendingPathComponent("calendar-snapshot"))
        request.httpMethod = "POST"; request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        URLSession.shared.dataTask(with: request) { _, response, error in
            let ok = error == nil && (response as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async { completion(ok ? "Calendar bridge: private board received the snapshot" : "Calendar bridge unavailable; local events remain readable") }
        }.resume()
    }
}
