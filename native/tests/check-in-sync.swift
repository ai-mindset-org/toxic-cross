import AppKit
import Foundation

let temp=FileManager.default.temporaryDirectory.appendingPathComponent("krest-sync-test-"+UUID().uuidString)
try FileManager.default.createDirectory(at:temp,withIntermediateDirectories:true)
defer{try? FileManager.default.removeItem(at:temp)}
let name="org.aimindset.krest.test."+UUID().uuidString
let defaults=UserDefaults(suiteName:name)!
defer{defaults.removePersistentDomain(forName:name)}
let address="https://private.example.test/board/index.html"
assert(CheckInConnection.enabled(address:address,defaults:defaults))
assert(!CheckInConnection.enabled(address:nil,defaults:defaults))
assert(!CheckInConnection.enabled(address:"https://apps.aimindset.org/krest/",defaults:defaults))
assert(!CheckInConnection.enabled(address:"https://sample.github.io/krest/",defaults:defaults))
assert(CheckInConnection.board(address,research:true)?.absoluteString == "https://private.example.test/board/#research")
let now=Date().addingTimeInterval(-30)
let event=CalendarMoment(id:"calendar-id|100.0|200.0",title:"PRIVATE TITLE",start:now.addingTimeInterval(-3600),end:now,allDay:false,declined:false,url:URL(string:"https://private.test/secret"),source:"fictional test")
let store=EventReviewStore(url:temp.appendingPathComponent("records.json"))
assert(store.save(event,feeling:-1,energy:1,reframe:"local note",now:now))
let first=store.records[0]
let rapidStore=EventReviewStore(url:temp.appendingPathComponent("rapid.json"))
assert(rapidStore.save(event,feeling:0,energy:0,reframe:"first",now:now))
let rapidFirst=rapidStore.records[0]
assert(rapidStore.save(event,feeling:1,energy:1,reframe:"second",now:now))
assert(CheckInWire.stamp(rapidStore.records[0].recorded) > CheckInWire.stamp(rapidFirst.recorded),"same-millisecond edits remain ordered on the wire")
func reply(_ entries:[EventReview]) -> Data {try! JSONSerialization.data(withJSONObject:["ok":true,"entries":entries.map(CheckInWire.object)])}
let wire=reply([first]);let decoded=CheckInWire.decode(wire)!
assert(CheckInWire.fingerprint(first) == CheckInWire.fingerprint(decoded[0]))
let encoded=String(data:wire,encoding:.utf8)!
assert(!encoded.contains(event.title) && !encoded.contains("private.test"))
let invalid=EventReview(occurrence:first.occurrence,start:first.start,end:first.end,recorded:first.recorded,feeling:3,energy:0,reframe:"")
assert(CheckInWire.decode(reply([invalid])) == nil)
assert(!store.merge([invalid]) && store.records == [first])
assert(CheckInWire.decode(reply([first,first])) == nil)
var malicious=CheckInWire.object(first);malicious["title"]="PRIVATE TITLE"
assert(CheckInWire.decode(try! JSONSerialization.data(withJSONObject:["ok":true,"entries":[malicious]])) == nil)
for value:Any in [true,0.5,3] {
    var raw=CheckInWire.object(first);raw["energy"]=value
    assert(CheckInWire.decode(try! JSONSerialization.data(withJSONObject:["ok":true,"entries":[raw]])) == nil)
}
let future=EventReview(occurrence:"future",start:first.start,end:first.end,recorded:Date().addingTimeInterval(600),feeling:0,energy:0,reframe:"")
assert(CheckInWire.decode(reply([future])) == nil)
let long=EventReview(occurrence:"long",start:first.start,end:first.end,recorded:first.recorded,feeling:0,energy:0,reframe:String(repeating:"a",count:281))
assert(CheckInWire.decode(reply([long])) == nil)
let receipt=temp.appendingPathComponent("receipt.json")
var requests=[URLRequest](),callbacks=[(Data?,Int)->Void]()
let sync=CheckInSync(receiptURL:receipt,defaults:defaults) {request,completion in requests.append(request);callbacks.append(completion)}
sync.sync(address:address,store:store)
assert(requests.count == 1 && requests[0].url?.path == "/board/check-ins/sync")
assert(requests[0].httpMethod == "POST")
assert(!String(data:requests[0].httpBody!,encoding:.utf8)!.contains("PRIVATE TITLE"))
callbacks.removeFirst()(nil,0)
assert(sync.pending(store)==1 && sync.status.contains("offline"))
assert(EventReviewStore(url:store.url).records==[first],"offline failure persists local ratings")
let web=EventReview(occurrence:"cal-legacy20hex",start:first.start,end:first.end,recorded:now.addingTimeInterval(1),feeling:2,energy:-2,reframe:"from browser")
sync.sync(address:address,store:store,force:true)
callbacks.removeFirst()(reply([first,web]),200)
assert(store.records.contains{CheckInWire.fingerprint($0) == CheckInWire.fingerprint(web)} && sync.pending(store)==0)
assert(EventReviewStore(url:store.url).records.contains{$0.occurrence == web.occurrence && $0.reframe == web.reframe},"web imports survive restart")
let restarted=CheckInSync(receiptURL:receipt,defaults:defaults) {_,completion in completion(nil,0)}
restarted.sync(address:address,store:store)
assert(restarted.pending(store)==0,"acknowledgements survive restart and offline poll")
// A response begun before an edit cannot replace the edit, and the queued save sends it next.
sync.sync(address:address,store:store,force:true)
assert(store.save(event,feeling:2,energy:2,reframe:"newer local",now:now.addingTimeInterval(3)))
sync.sync(address:address,store:store,force:true)
callbacks.removeFirst()(reply([first,web]),200)
assert(store.review(event)?.reframe == "newer local" && sync.pending(store)==1 && callbacks.count==1)
let latest=store.review(event)!
callbacks.removeFirst()(reply([latest,web]),200)
assert(sync.pending(store)==0)
let newer=EventReview(occurrence:latest.occurrence,start:latest.start,end:latest.end,recorded:now.addingTimeInterval(4),feeling:0,energy:-1,reframe:"newer browser")
sync.sync(address:address,store:store,force:true);callbacks.removeFirst()(reply([newer,web]),200)
assert(store.review(event)?.reframe == "newer browser")
// A malformed reply changes neither records nor the last receipt.
let before=store.records
sync.sync(address:address,store:store,force:true);callbacks.removeFirst()(reply([invalid]),200)
assert(store.records==before && sync.status.contains("invalid reply"))
// Disabling sync while in flight fences off the old reply and sends nothing else.
sync.sync(address:address,store:store,force:true)
defaults.set(false,forKey:CheckInConnection.enabledKey)
sync.sync(address:address,store:store,force:true)
callbacks.removeFirst()(reply([latest,web]),200)
assert(store.records==before && sync.status.contains("sync off"))
let count=requests.count
sync.sync(address:nil,store:store,force:true)
sync.sync(address:"https://apps.aimindset.org/krest/",store:store,force:true)
assert(requests.count==count)
// Verify the private bridge keeps the exact native fingerprint; legacy IDs remain readable.
assert(EventReview.key(event).count==64)
let _=NSApplication.shared
let panel=ПанельView(frame:NSRect(x:0,y:0,width:520,height:690))
panel.boardAddress=address;panel.reviews=store;panel.reviewSyncEnabled=true
panel.checkInReceipt(sync.status,enabled:true)
for mode in ["day","history","settings","now"] {panel.select(mode);assert(panel.frame.size==NSSize(width:520,height:690))}
func descendants(_ view:NSView)->[NSView] {view.subviews.flatMap{[$0]+descendants($0)}}
panel.select("day")
var researchOpened=false
panel.openResearch={researchOpened=true}
descendants(panel).compactMap{$0 as? NSButton}.first{$0.accessibilityLabel()=="open research board"}!.performClick(nil)
assert(researchOpened)
print("check-in sync: offline persistence; browser import; newest conflicts/in-flight edits; durable per-board receipts; invalid records; opt-out fencing; public demo exclusion; research navigation; 520×690 passed")
