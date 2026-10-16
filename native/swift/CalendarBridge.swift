import AppKit
import EventKit
import Foundation

struct CalendarMoment: Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let allDay: Bool
    let declined: Bool
    let url: URL?
    let source: String
    var addedAt: Date? = nil
    var weight: Double { end.timeIntervalSince(start) > 90*60 ? 1.5 : 1 }
    func phase(at now: Date) -> String {
        if declined { return "declined" }
        if allDay { return "all day" }
        if end <= now { return "earlier" }
        if start <= now { return "now" }
        return "upcoming"
    }
}
struct CalendarFrame {
    let events: [CalendarMoment]
    let source: String
    let fetched: Date?
    let start: Date?
    let end: Date?
    let issue: String?
    var snapshot = false
    var maxAge:TimeInterval = 3600
    var observed: Bool { fetched != nil && issue == nil }
    func fresh(at now: Date) -> Bool { observed && fetched.map { now.timeIntervalSince($0) >= -300 && now.timeIntervalSince($0) <= maxAge } == true }
    func today(at now: Date) -> [CalendarMoment] {
        let start=Calendar.current.startOfDay(for:now),end=Calendar.current.date(byAdding:.day,value:1,to:start)!
        return events.filter{$0.start < end && $0.end > start}.sorted{$0.start < $1.start}
    }
    func pressure(at now: Date) -> (remaining: Double, elapsed: Double, freeHours: Double) {
        let events=today(at:now).filter{!$0.allDay && !$0.declined}
        var remaining=0.0, elapsed=0.0
        for e in events {
            let part=max(0,min(1,e.end.timeIntervalSince(now)/max(1,e.end.timeIntervalSince(e.start))))
            remaining += e.weight*part;elapsed += e.weight*(1-part)
        }
        let cal=Calendar.current,day=cal.startOfDay(for:now)
        let lo=max(now,cal.date(byAdding:.hour,value:9,to:day)!),hi=cal.date(byAdding:.hour,value:19,to:day)!
        var intervals=events.compactMap { e -> (Date,Date)? in
            let a=max(lo,e.start),b=min(hi,e.end);return b>a ? (a,b):nil
        }.sorted{$0.0<$1.0}
        var busy=0.0
        if var run=intervals.first {
            intervals.removeFirst()
            for p in intervals { if p.0<=run.1 {run.1=max(run.1,p.1)}else{busy+=run.1.timeIntervalSince(run.0);run=p} }
            busy+=run.1.timeIntervalSince(run.0)
        }
        return (remaining,elapsed,max(0,hi.timeIntervalSince(lo)-busy)/3600)
    }
    func receipt(at now:Date) -> String {
        guard let fetched else {return issue ?? "Calendar not observed"}
        let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX");f.dateFormat="dd MMM HH:mm z"
        return source+" · captured "+f.string(from:fetched)+" · "+(fresh(at:now) ? "fresh":"stale")+(snapshot ? " · read-only snapshot":"")+(issue.map{" · "+$0} ?? "")
    }
}

enum CalendarBridge {
    static let snapshotURL=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/calendar-control/google-snapshot.json")
    static func decode(_ data:Data,now:Date=Date(),hidden:Set<String>=[],none:Bool=false) -> CalendarFrame? {
        guard let o=try? JSONSerialization.jsonObject(with:data) as? [String:Any],o["schemaVersion"] as? Int == 1,(o["calendarCount"] as? Int ?? 0)>0,
              o["source"] as? String == "google-calendar-connector",
              let fetched=(o["fetchedAt"] as? String).flatMap(Свежесть.дата),fetched<=now.addingTimeInterval(300),
              let start=(o["rangeStart"] as? String).flatMap(Свежесть.дата),let end=(o["rangeEnd"] as? String).flatMap(Свежесть.дата),end>start,
              let raw=o["events"] as? [[String:Any]] else {return nil}
        var seen=Set<String>(),events=[CalendarMoment]()
        for r in raw {
            if none {continue}
            if let calendarID=r["calendarID"] as? String,hidden.contains("google:"+calendarID) {continue}
            guard let title=r["title"] as? String,let a=(r["start"] as? String).flatMap(Свежесть.дата),let b=(r["end"] as? String).flatMap(Свежесть.дата),b>a else {return nil}
            let id=(r["eventID"] as? String ?? title)+"|"+String(a.timeIntervalSince1970)+"|"+String(b.timeIntervalSince1970)
            guard seen.insert(id).inserted else {continue}
            let notes=r["notes"] as? String ?? ""
            let u=(r["url"] as? String).flatMap(URL.init(string:)).flatMap { ["https","http"].contains($0.scheme ?? "") ? $0:nil }
            events.append(CalendarMoment(id:id,title:title,start:a,end:b,allDay:r["allDay"] as? Bool ?? false,declined:notes.contains("[guest-declined]"),url:u,source:"Google snapshot",addedAt:(r["addedAt"] as? String).flatMap(Свежесть.дата)))
        }
        let day=Calendar.current.startOfDay(for:now),next=Calendar.current.date(byAdding:.day,value:1,to:day)!
        let coverage=o["coverageNote"] as? String
        return CalendarFrame(events:events,source:"Calendar Control / Google",fetched:fetched,start:start,end:end,issue:start>day || end<next ? "Today is outside full snapshot coverage" : coverage,snapshot:true,maxAge:o["transport"] as? String == "spark-desktop" ? 120:3600)
    }
    static func load(now:Date=Date()) -> CalendarFrame {
        if FileManager.default.fileExists(atPath:snapshotURL.path) {
            let settings=UserDefaults(suiteName:"dev.alex.calendar-control")
            let hidden=Set(settings?.stringArray(forKey:"hiddenCalendarIDs") ?? [])
            guard let bytes=try? Data(contentsOf:snapshotURL),let value=decode(bytes,now:now,hidden:hidden,none:settings?.bool(forKey:"noCalendarsSelected") ?? false) else {return CalendarFrame(events:[],source:"Google snapshot",fetched:nil,start:nil,end:nil,issue:"Calendar snapshot could not be read")}
            return value
        }
        let auth=EKEventStore.authorizationStatus(for:.event)
        let allowed:Bool
        if #available(macOS 14.0,*) {allowed=auth == .fullAccess}else{allowed=auth == .authorized}
        guard allowed else {return CalendarFrame(events:[],source:"Calendar",fetched:nil,start:nil,end:nil,issue:"Open Calendar Control to connect a calendar")}
        let store=Календарь.хранилище,cal=Calendar.current,start=cal.startOfDay(for:now),end=cal.date(byAdding:.day,value:8,to:start)!
        let events=store.events(matching:store.predicateForEvents(withStart:start,end:end,calendars:nil)).filter{$0.status != .canceled}.map { e in
            CalendarMoment(id:(e.eventIdentifier ?? e.calendarItemIdentifier)+"|"+String(e.startDate.timeIntervalSince1970),title:e.title ?? "Untitled event",start:e.startDate,end:e.endDate,allDay:e.isAllDay,declined:(e.attendees ?? []).contains{$0.isCurrentUser && $0.participantStatus == .declined},url:e.url,source:"On this Mac")
        }
        return CalendarFrame(events:events,source:"macOS Calendar",fetched:now,start:start,end:end,issue:nil)
    }
    static func day(_ frame:CalendarFrame,now:Date=Date()) -> День? {
        guard frame.observed,frame.fresh(at:now) else{return nil}
        let p=frame.pressure(at:now),support=p.freeHours>0 ? min(4,p.freeHours*0.5):-2
        let today=frame.today(at:now).filter{!$0.allDay && !$0.declined}
        let arms=[День.Луч(имя:"обязательства",сумма:p.remaining,штук:today.filter{$0.end>now}.count,верх:[]),День.Луч(имя:"ресурсы",сумма:support,штук:1,верх:[]),День.Луч(имя:"будущее",сумма:0,штук:0,верх:[]),День.Луч(имя:"прошлое",сумма:p.elapsed,штук:today.filter{$0.end<=now}.count,верх:[])]
        let total=max(1,arms.reduce(0){$0+abs($1.сумма)}/2),f=DateFormatter();f.dateFormat="yyyy-MM-dd"
        return День(дата:f.string(from:now),собрано:ISO8601DateFormatter().string(from:now),лучи:arms,x:max(-1,-p.elapsed/total),y:max(-1,min(1,-(p.remaining-support)/total)),источники:[День.Источник(имя:"календарь",статус:"live")],rulesVersion:"calendar-v2",живой:true,режим:.календарь)
    }
}
