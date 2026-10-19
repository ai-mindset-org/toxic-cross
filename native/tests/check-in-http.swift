import Foundation

// The Python harness owns an ephemeral loopback server and an isolated temporary journal.
let address=CommandLine.arguments[1]
let temp=URL(fileURLWithPath:CommandLine.arguments[2])
guard let endpoint=URL(string:address),endpoint.host == "127.0.0.1",temp.lastPathComponent.hasPrefix("krest-http-") else{fatalError("Isolated loopback harness required")}
func waitFor(_ predicate:()->Bool) {
    let deadline=Date().addingTimeInterval(12)
    while !predicate() && Date()<deadline {RunLoop.current.run(until:Date().addingTimeInterval(0.01))}
    assert(predicate(),"loopback HTTP operation timed out")
}
func request(_ path:String,_ body:[String:Any]?=nil) -> Any {
    var request=URLRequest(url:endpoint.appendingPathComponent(path));request.timeoutInterval=8
    if let body {request.httpMethod="POST";request.httpBody=try! JSONSerialization.data(withJSONObject:body);request.setValue("application/json",forHTTPHeaderField:"Content-Type")}
    var finished=false,result:Any?,code=0
    let session=URLSession(configuration:.ephemeral)
    session.dataTask(with:request) {data,response,error in
        DispatchQueue.main.async {
            code=(response as? HTTPURLResponse)?.statusCode ?? 0
            if error == nil,let data {result=try? JSONSerialization.jsonObject(with:data)}
            finished=true
        }
    }.resume()
    waitFor{finished};session.finishTasksAndInvalidate()
    assert(code==200,"loopback HTTP failure: \(path), \(code)")
    return result!
}
let suite="org.aimindset.krest.http."+UUID().uuidString
let defaults=UserDefaults(suiteName:suite)!
defer{defaults.removePersistentDomain(forName:suite)}
let store=EventReviewStore(url:temp.appendingPathComponent("native-records.json"))
let sync=CheckInSync(receiptURL:temp.appendingPathComponent("native-receipt.json"),defaults:defaults)
func exchange() {
    var complete=false
    sync.onChange={status in if !status.contains("syncing") {complete=true}}
    sync.sync(address:address,store:store,force:true)
    waitFor{complete}
    assert(sync.status.contains("checked"),sync.status)
    assert(sync.pending(store)==0,"canonical round trip must acknowledge every local record")
}
let now=Date().addingTimeInterval(-60)
let event=CalendarMoment(id:"fictional-http-event|100.0|200.0",title:"EXCLUDED FIXTURE TITLE",start:now.addingTimeInterval(-3600),end:now,allDay:false,declined:false,url:nil,source:"fictional HTTP test")
let browser=EventReview(occurrence:EventReview.key(event),start:event.start,end:event.end,recorded:now,feeling:-1,energy:1,reframe:"browser first")
let posted=request("check-in",CheckInWire.object(browser)) as! [String:Any]
let serverEntry=posted["entry"] as! [String:Any]
assert((serverEntry["recorded"] as! String).hasSuffix("+00:00"),"exercise real Python timestamp normalization")
exchange()
assert(store.review(event)?.reframe=="browser first","browser POST must reach native production transport")
assert(EventReviewStore(url:store.url).review(event)?.feeling == -1,"browser import is durable")
assert(store.save(event,feeling:2,energy:2,reframe:"native next",now:now.addingTimeInterval(1)))
exchange()
let rows=request("check-ins") as! [[String:Any]]
assert(rows.count==1 && rows[0]["reframe"] as? String == "native next","native save must reach the actual API journal")
assert(rows[0]["feeling"] as? Int == 2)
// Another browser occurrence joins the union, while a newer browser edit wins the shared occurrence.
let other=EventReview(occurrence:"legacy-browser-http",start:event.start,end:event.end,recorded:now.addingTimeInterval(2),feeling:0,energy:-1,reframe:"browser independent")
_ = request("check-in",CheckInWire.object(other))
assert(store.save(event,feeling:-2,energy:-2,reframe:"older unsynced native",now:now.addingTimeInterval(3)))
let winner=EventReview(occurrence:browser.occurrence,start:event.start,end:event.end,recorded:now.addingTimeInterval(4),feeling:1,energy:0,reframe:"newest browser")
_ = request("check-in",CheckInWire.object(winner))
exchange()
assert(store.records.count==2 && store.review(event)?.reframe=="newest browser","newest remote edit wins and unrelated browser record is retained")
let canonical=request("check-ins") as! [[String:Any]]
assert(Set(canonical.compactMap{$0["occurrence"] as? String})==Set(store.records.map(\.occurrence)))
let before=store.records
exchange()
assert(store.records==before && sync.pending(store)==0,"repeat sync is idempotent with +00:00 server dates")
let files=try! FileManager.default.contentsOfDirectory(at:temp,includingPropertiesForKeys:nil)
assert(files.contains{$0.lastPathComponent.hasPrefix("native-receipt.")},"real exchange persists acknowledgement")
print("PASS real loopback HTTP: web POST → native store; native save → server GET; newest browser conflict; union; repeat sync 0 pending; Python +00:00 dates; no personal source access")
