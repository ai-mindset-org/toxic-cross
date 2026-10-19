import AppKit
import Foundation
let fixture = try Data(contentsOf: URL(fileURLWithPath: "assets/демо.json"))
let day = День.разобрать(fixture, живой: false)!
assert(day.лучи.count == 4 && day.режим == .образец)
assert(День.разобрать(Data("{\"лучи\":{}}".utf8), живой: true) == nil)
var bad = try JSONSerialization.jsonObject(with: fixture) as! [String: Any]
bad["баланс"] = ["x": 99, "y": 0]
let invalid = try JSONSerialization.data(withJSONObject: bad)
assert(День.разобрать(invalid, живой: true) == nil)
let a = Свежесть.дата("2026-09-27T22:47+01:00")!
let b = Свежесть.дата("2026-09-27T21:47:00Z")!
assert(a == b)
assert(Свежесть.описание("2026-09-27T22:47+01:00", now: a.addingTimeInterval(7200)).contains("stale (2 h)"))
for suffix in ["", "/", "/index.html", "/контекст.json"] {
 assert(Свежесть.endpoint("https://example.test/base" + suffix)?.path == "/base/контекст.json")
}
assert(Свежесть.endpoint("file:///etc/passwd") == nil)
assert(Свежесть.endpoint("https://name:secret@example.test") == nil)
print("contract: valid/invalid payload, date/timezone, staleness, URL normalization passed")

var sourcePayload=try JSONSerialization.jsonObject(with:fixture) as! [String:Any]
let capture="2026-09-27T09:00:00Z",expiry="2026-09-27T15:00:00Z",checked="2026-09-27T21:47:00Z"
sourcePayload["источники"]=["обещания":["статус":"quiet","заметка":"Snapshot is 12.3 h old","capturedAt":capture,"checkedAt":checked,"expiresAt":expiry],"техничка":["статус":"live","когда":checked,"expiresAt":expiry]]
let staleSources=День.разобрать(try JSONSerialization.data(withJSONObject:sourcePayload),живой:true)!
let promiseSource=staleSources.источники.first{$0.имя=="обещания"}!
assert(promiseSource.статус=="quiet" && promiseSource.note=="Snapshot is 12.3 h old","presentation preserves raw receipt and status")
assert(promiseSource.displayStatus(at:b)=="snapshot / limited freshness · expired")
assert(!promiseSource.displayStatus(at:Свежесть.дата(capture)!).contains("expired"))
assert(promiseSource.displayStatus(at:Свежесть.дата(expiry)!).contains("expired"),"expiry boundary is inclusive")
assert(promiseSource.capturedAt==capture && promiseSource.checkedAt==checked && promiseSource.expiresAt==expiry)
assert(promiseSource.timingReceipt.contains(capture) && promiseSource.timingReceipt.contains(checked),"fresh check never refreshes an old capture")
assert(staleSources.источники.first{$0.имя=="техничка"}!.displayStatus(at:b)=="observed · expired","expiresAt overrides a live label too")
assert(staleSources.источники.first{$0.имя=="техничка"}!.checkedAt==checked,"legacy check timestamp is retained")
assert(День.Источник(имя:"test",статус:"quiet").displayStatus(at:b)=="snapshot / limited freshness")
assert(День.Источник(имя:"test",статус:"live",expiresAt:"invalid").displayStatus(at:b)=="observed · expiry unknown")
print("source receipts: quiet has no zero-activity claim; expiry boundary/live override; distinct capture/check times; malformed expiry passed")

let temp=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at:temp,withIntermediateDirectories:true)
defer { try? FileManager.default.removeItem(at:temp) }
let store=BalanceHistory(url:temp.appendingPathComponent("history.json"))
assert(BalanceRecord.make(day,sourceID:"fixture",origin:"test") == nil, "demo must never enter history")
let live=День.разобрать(fixture,живой:true)!
let record=BalanceRecord.make(live,sourceID:"A",origin:"test")!
assert(store.append(record));assert(!store.append(record));assert(store.records.count==1)
assert(BalanceHistory(url:store.url).records==store.records)
assert(store.points(sourceID:"B",mode:"борт").isEmpty)
let badURL=temp.appendingPathComponent("broken.json");try Data("broken".utf8).write(to:badURL)
let corrupt=BalanceHistory(url:badURL);assert(!corrupt.append(record));assert(try! String(contentsOf:badURL,encoding:.utf8)=="broken")
let listing=Data("<a href=\"2026-09-16.json\">ok</a><a href=\"https://other.test/2026-09-17.json\">bad</a><a href=\"../2026-09-18.json\">bad</a>".utf8)
assert(BalanceHistory.archiveNames(listing)==["2026-09-16.json"])
assert(BalanceRecord.source("https://example.test/")==BalanceRecord.source("https://example.test/index.html"))
let permissions=try FileManager.default.attributesOfItem(atPath:store.url.path)[.posixPermissions] as! Int
assert(permissions==0o600)
print("history: demo exclusion, persistence, deduplication, source separation, corrupt-file preservation, archive allowlist, permissions passed")
let app=NSApplication.shared
let panel=ПанельView(frame:NSRect(x:0,y:0,width:ПанельView.width,height:ПанельView.height))
panel.показать(day);panel.layoutSubtreeIfNeeded()
for mode in ["now","day","history","settings"] { panel.select(mode);panel.layoutSubtreeIfNeeded();assert(panel.frame.width==520 && panel.frame.height==690) }
assert(Знак.образ(x:0.2,y:-0.4,тревога:false).isTemplate)
print("native: four modes keep panel geometry; menu mark is template")
let ref=Свежесть.дата("2026-09-29T11:00:00Z")!
let raw:[String:Any]=["schemaVersion":1,"source":"google-calendar-connector","calendarCount":1,"fetchedAt":"2026-09-29T10:55:00Z","rangeStart":"2026-09-28T00:00:00Z","rangeEnd":"2026-10-01T00:00:00Z","events":[
 ["eventID":"one","title":"test one","start":"2026-09-29T10:00:00Z","end":"2026-09-29T12:00:00Z","allDay":false],
 ["eventID":"two","title":"test two","start":"2026-09-29T11:00:00Z","end":"2026-09-29T12:00:00Z","allDay":false],
 ["eventID":"two","title":"test two","start":"2026-09-29T11:00:00Z","end":"2026-09-29T12:00:00Z","allDay":false],
 ["eventID":"three","title":"declined","start":"2026-09-29T10:00:00Z","end":"2026-09-29T16:00:00Z","allDay":false,"notes":"[guest-declined]"]]]
let frame=CalendarBridge.decode(try! JSONSerialization.data(withJSONObject:raw),now:ref)!
assert(frame.events.count==3 && frame.fresh(at:ref))
assert(abs(frame.pressure(at:ref).remaining-1.75)<0.001)
assert(abs(frame.pressure(at:ref).elapsed-0.75)<0.001)
assert(frame.events[0].phase(at:ref)=="now")
assert(frame.events[0].phase(at:ref.addingTimeInterval(3600))=="earlier")
assert(frame.pressure(at:ref.addingTimeInterval(3600)).remaining==0)
let local=CalendarBridge.day(frame,now:ref)!
assert(local.rulesVersion=="calendar-v2" && local.режим == .календарь)
assert(CalendarBridge.day(frame,now:ref.addingTimeInterval(7200))==nil)
var malformed=raw;malformed["fetchedAt"]="tomorrow"
assert(CalendarBridge.decode(try! JSONSerialization.data(withJSONObject:malformed),now:ref)==nil)
var partial=raw;partial["rangeStart"]="2026-09-29T10:00:00Z"
assert(CalendarBridge.decode(try! JSONSerialization.data(withJSONObject:partial),now:ref)?.observed==false)
print("calendar: phases, elapsed load, duplicate invitations, declined exclusion, stale/partial refusal passed")

let close=Calendar.current.date(bySettingHour:19,minute:0,second:0,of:ref)!
assert(abs(frame.pressure(at:ref).freeHours-max(0,close.timeIntervalSince(ref)/3600-1))<0.001,"overlapping busy intervals must be counted once")
let allDay=CalendarMoment(id:"all-day",title:"holiday",start:ref.addingTimeInterval(-36000),end:ref.addingTimeInterval(36000),allDay:true,declined:false,url:nil,source:"test")
let withAllDay=CalendarFrame(events:frame.events+[allDay],source:frame.source,fetched:frame.fetched,start:frame.start,end:frame.end,issue:nil)
assert(withAllDay.pressure(at:ref).remaining==frame.pressure(at:ref).remaining)
print("calendar: overlap union and all-day exclusion passed")

let reviews=EventReviewStore(url:temp.appendingPathComponent("checkins.json"))
let reviewedEvent=frame.events[0]
assert(reviews.save(reviewedEvent,feeling:-1,energy:2,reframe:"One useful boundary",now:ref))
assert(reviews.review(reviewedEvent)?.feeling == -1)
assert(!reviews.save(reviewedEvent,feeling:3,energy:0,reframe:"invalid"))
assert(reviews.summary(on:ref)?.count == 1)
let reviewBytes=try! String(contentsOf:reviews.url,encoding:.utf8)
assert(!reviewBytes.contains(reviewedEvent.title),"event titles must stay out of check-in storage")
assert((try! FileManager.default.attributesOfItem(atPath:reviews.url.path)[.posixPermissions] as! Int)==0o600)
assert(EventReviewStore(url:reviews.url).records==reviews.records)
var notice=EventNoticePolicy()
let ending=CalendarMoment(id:"ending",title:"private title",start:ref.addingTimeInterval(-3600),end:ref,allDay:false,declined:false,url:nil,source:"test")
let noticeFrame=CalendarFrame(events:[ending],source:"test",fetched:ref,start:ref.addingTimeInterval(-7200),end:ref.addingTimeInterval(7200),issue:nil)
assert(notice.evaluate(noticeFrame,now:ref.addingTimeInterval(-30),enabled:true,reviewed:[]).isEmpty,"startup never backfills reminders")
assert(notice.evaluate(noticeFrame,now:ref.addingTimeInterval(15),enabled:true,reviewed:[]).count==1)
assert(notice.evaluate(noticeFrame,now:ref.addingTimeInterval(45),enabled:true,reviewed:[]).isEmpty,"one notification per occurrence")
var wakePolicy=EventNoticePolicy()
_ = wakePolicy.evaluate(noticeFrame,now:ref.addingTimeInterval(-900),enabled:true,reviewed:[])
assert(wakePolicy.evaluate(noticeFrame,now:ref.addingTimeInterval(30),enabled:true,reviewed:[]).isEmpty,"wake never replays a backlog")
print("check-ins: range validation, private persistence, title exclusion, permissions; reminders: bootstrap, transition, duplicates and wake passed")

let uiNow=Date(),uiStart=Calendar.current.startOfDay(for:uiNow)
let uiEvent=CalendarMoment(id:"native-ui-test",title:"Fictional UI event",start:uiNow.addingTimeInterval(-600),end:uiNow.addingTimeInterval(1200),allDay:false,declined:false,url:nil,source:"fictional test")
panel.reviews=reviews;panel.saveReview={event,feeling,energy,note in reviews.save(event,feeling:feeling,energy:energy,reframe:note)}
panel.calendar(CalendarFrame(events:[uiEvent],source:"fictional test",fetched:uiNow,start:uiStart,end:uiStart.addingTimeInterval(86400),issue:nil));panel.select("day")
func descendants(_ view:NSView)->[NSView] {view.subviews.flatMap{[$0]+descendants($0)}}
let checkInButton=descendants(panel).compactMap{$0 as? NSButton}.first{$0.accessibilityLabel()=="check in"}!
assert(checkInButton.toolTip?.contains("optional private-board sync") == true)
checkInButton.performClick(nil)
let ratings=descendants(panel).compactMap{$0 as? KrestPopUp};assert(ratings.count==2)
ratings[0].changed?(4);ratings[1].changed?(1)
let noteField=descendants(panel).compactMap{$0 as? NSTextField}.first{$0.placeholderString?.contains("Optional") == true}!
noteField.stringValue="One fictional next step"
descendants(panel).compactMap{$0 as? NSButton}.first{$0.accessibilityLabel()=="save check-in"}!.performClick(nil)
assert(reviews.review(uiEvent)?.feeling==2 && reviews.review(uiEvent)?.energy == -1)
assert(reviews.review(uiEvent)?.reframe=="One fictional next step")
assert(!descendants(panel).contains{$0===noteField},"save returns from the form to the day")
print("native control walk: Day → check in → feeling/energy → note → save → Day; private temporary store only passed")

assert(day.источники.allSatisfy{Copy.name($0.имя).range(of:"[А-Яа-яЁё]",options:.regularExpression)==nil},"fixture source labels must be English")

// History comparison uses observation time and source identity, never receipt order.
func historyRecord(_ id:String,_ timestamp:String,source:String="A",mode:String="борт",rules:String="v1",sum:Double=10,count:Int=2,x:Double=0.1,y:Double = -0.2,missing:Bool=false) -> BalanceRecord {
    let date=Свежесть.дата(timestamp)!
    return BalanceRecord(id:id,sourceID:source,mode:mode,day:String(timestamp.prefix(10)),collected:date,received:Date(),origin:"test",rules:rules,x:x,y:y,sums:missing ? [:]:["обязательства":sum],counts:missing ? [:]:["обязательства":count],sources:[:])
}
let old=historyRecord("old","2026-10-01T23:00:00Z")
let selected=historyRecord("selected","2026-10-03T00:00:00Z",sum:7,count:3,x:0.3,y:0.1)
let other=historyRecord("other","2026-10-02T23:59:00Z",source:"B")
let otherMode=historyRecord("mode","2026-10-02T23:58:00Z",mode:"календарь")
let simultaneous=historyRecord("same-time","2026-10-03T00:00:00Z")
let future=historyRecord("future","2026-10-04T00:00:00Z")
let comparison=HistoryComparison.find(for:selected,in:[future,other,selected,old,otherMode,simultaneous])!
assert(comparison.previous.id==old.id)
assert(comparison.interval==90000 && comparison.intervalText=="1d 1h 0m 0s")
assert(comparison.sumDelta("обязательства")==(-3) && comparison.countDelta("обязательства")==1)
assert(comparison.sumDelta("ресурсы")==nil && comparison.countDelta("ресурсы")==nil)
assert(HistoryComparison.find(for:old,in:[old,other,future])==nil)
let ruleChange=historyRecord("rules","2026-10-02T23:00:00Z",rules:"v2")
let changed=HistoryComparison.find(for:selected,in:[old,ruleChange])!
assert(changed.previous.id=="rules" && !changed.comparable && changed.sumDelta("обязательства")==nil)
let absent=historyRecord("absent","2026-10-02T23:00:00Z",missing:true)
assert(HistoryComparison.find(for:selected,in:[absent])!.sumDelta("обязательства")==nil)
var utc=Calendar(identifier:.gregorian);utc.timeZone=TimeZone(secondsFromGMT:0)!
assert(!HistoryComparison.connects(old,selected,calendar:utc),"Oct 2 has no observation, despite only a 25-hour interval")
let next=historyRecord("next","2026-10-02T00:00:00Z")
assert(HistoryComparison.connects(old,next,calendar:utc))
assert(!HistoryComparison.connects(old,other,calendar:utc))
assert(!HistoryComparison.connects(old,ruleChange,calendar:utc))
let beforeDST=historyRecord("beforeDST","2026-10-25T01:30:00+01:00")
let afterDST=historyRecord("afterDST","2026-10-25T01:30:00Z")
assert(HistoryComparison.find(for:afterDST,in:[beforeDST])!.interval==3600,"equal wall times across DST are one actual hour apart")
assert(store.records.count==1,"comparison does not write history")
print("history comparison: prior capture, source/mode isolation, signed deltas, first/missing/rule-change states, day gaps, DST and no writes passed")

// Shell navigation and actual field-editor focus, using an offscreen window.
for migrated in [false,true] {
    for stored in [nil,false,true] as [Bool?] {
        let result=AIMPinPolicy.resolve(stored:stored,migrated:migrated)
        assert(result.pinned == (stored ?? false))
        assert(result.writePinned == (!migrated && stored == nil))
    }
}
func panelKey(_ code:UInt16,_ flags:NSEvent.ModifierFlags=[],_ chars:String="") -> NSEvent {
    NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:flags,timestamp:0,windowNumber:0,context:nil,characters:chars,charactersIgnoringModifiers:chars,isARepeat:false,keyCode:code)!
}
let navWindow=NSWindow(contentRect:panel.frame,styleMask:.titled,backing:.buffered,defer:false)
navWindow.contentView=panel
panel.select("history")
assert(panel.handlePanelKey(panelKey(43,.command,",")))
assert(panel.navigation.current=="settings" && panel.navigation.previous=="history")
assert(panel.handlePanelKey(panelKey(43,.command,",")))
assert(panel.navigation.previous=="history","repeated Settings must retain its return destination")
let edit=NSTextField(frame:NSRect(x:0,y:0,width:100,height:20));panel.addSubview(edit)
navWindow.makeFirstResponder(edit)
assert(navWindow.firstResponder is NSTextView,"real AppKit field editor is active")
assert(panel.handlePanelKey(panelKey(53)))
assert(panel.navigation.current=="history")
assert(!(navWindow.firstResponder is NSTextView),"Escape clears the old editor before rebuilding the previous view")
assert(!panel.handlePanelKey(panelKey(53)),"next Escape belongs to surface hide")
assert(panel.frame.size==NSSize(width:520,height:690))
edit.removeFromSuperview()
let recorderDefaults=UserDefaults(suiteName:"org.aimindset.krest.contract-recorder")!
recorderDefaults.removePersistentDomain(forName:"org.aimindset.krest.contract-recorder")
let recorderStore=FamilyHotkeyStore(owner:FamilyHotkeys.krest,fallback:Delegate.hotkeyStore.fallback,bundle:"org.aimindset.krest.contract-recorder",defaults:recorderDefaults)
panel.hotkeyStore=recorderStore;panel.select("settings")
func recorderIn(_ view:NSView)->FamilyHotkeyField? {
    if let field=view as? FamilyHotkeyField{return field}
    return view.subviews.compactMap{recorderIn($0)}.first
}
let recorder=recorderIn(panel)!
recorder.performClick(nil);assert(recorder.recording)
panel.показать(day);assert(recorder.recording,"source refresh must preserve the active recorder")
assert(panel.handlePanelKey(panelKey(53)))
assert(!recorder.recording && panel.navigation.current=="settings","first Escape only cancels recording")
assert(recorderStore.current==Delegate.hotkeyStore.fallback)
assert(panel.handlePanelKey(panelKey(53)) && panel.navigation.current=="history")
recorderDefaults.removePersistentDomain(forName:"org.aimindset.krest.contract-recorder")
print("shell: six pin migration states, local Settings, previous view, text-editor Escape, recorder priority, source-refresh focus and fixed geometry passed")

assert(KrestKeyScope.accepts(shown:true,modal:false,sheet:false,menu:false,eventWindow:nil,panelWindow:100))
assert(KrestKeyScope.accepts(shown:true,modal:false,sheet:false,menu:false,eventWindow:100,panelWindow:100))
assert(!KrestKeyScope.accepts(shown:true,modal:false,sheet:false,menu:false,eventWindow:200,panelWindow:100),"foreign window retains Cmd-comma and Escape")
assert(!KrestKeyScope.accepts(shown:true,modal:true,sheet:false,menu:false,eventWindow:nil,panelWindow:100),"modal alert owns even windowless key events")
assert(!KrestKeyScope.accepts(shown:true,modal:false,sheet:true,menu:false,eventWindow:100,panelWindow:100))
assert(!KrestKeyScope.accepts(shown:true,modal:false,sheet:false,menu:true,eventWindow:nil,panelWindow:100))
assert(!KrestKeyScope.accepts(shown:false,modal:false,sheet:false,menu:false,eventWindow:nil,panelWindow:100))
print("shell scope: windowless popover keys accepted; foreign window/modal alert/sheet/menu/hidden surface leave keys untouched")
