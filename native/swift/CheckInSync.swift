import Foundation
import CryptoKit

/// Wire dates are ISO8601; the existing local Swift Date encoding stays unchanged.
enum CheckInWire {
    static func stamp(_ date: Date) -> String {
        let f=ISO8601DateFormatter();f.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        return f.string(from:date)
    }
    static func object(_ value: EventReview) -> [String:Any] {
        ["occurrence":value.occurrence,"start":stamp(value.start),"end":stamp(value.end),"recorded":stamp(value.recorded),"feeling":value.feeling,"energy":value.energy,"reframe":value.reframe]
    }
    static func fingerprint(_ value: EventReview) -> String {
        let data=try! JSONSerialization.data(withJSONObject:object(value),options:.sortedKeys)
        return SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()
    }
    static func decode(_ data: Data, now: Date = Date()) -> [EventReview]? {
        guard data.count <= 8_000_000,let reply=try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              reply["ok"] as? Bool == true,let entries=reply["entries"] as? [[String:Any]],entries.count <= 5000 else{return nil}
        var values=[EventReview](),seen=Set<String>()
        for item in entries {
            guard Set(item.keys) == Set(["occurrence","start","end","recorded","feeling","energy","reframe"]),
                  let occurrence=item["occurrence"] as? String,seen.insert(occurrence).inserted,
                  let start=(item["start"] as? String).flatMap(Свежесть.дата),let end=(item["end"] as? String).flatMap(Свежесть.дата),
                  let recorded=(item["recorded"] as? String).flatMap(Свежесть.дата),let feeling=integer(item["feeling"]),let energy=integer(item["energy"]),
                  let reframe=item["reframe"] as? String else{return nil}
            let value=EventReview(occurrence:occurrence,start:start,end:end,recorded:recorded,feeling:feeling,energy:energy,reframe:reframe)
            guard value.valid(at:now) else{return nil};values.append(value)
        }
        return values
    }
    private static func integer(_ raw:Any?) -> Int? {
        guard let number=raw as? NSNumber,CFGetTypeID(number) != CFBooleanGetTypeID(),number.doubleValue.rounded() == number.doubleValue,(-2...2).contains(number.doubleValue) else{return nil}
        return number.intValue
    }
}

/// A configured board is the user's connection consent. Known public demonstration hosts are excluded.
enum CheckInConnection {
    static let enabledKey="KrestSyncCheckInsWithBoard"
    static func root(_ address:String?) -> URL? {
        guard let address,let endpoint=Свежесть.endpoint(address),let host=endpoint.host?.lowercased(),
              host != "apps.aimindset.org",host != "aimindset.org",host != "www.aimindset.org",
              !host.hasSuffix(".github.io"),!host.hasSuffix(".chatgpt.site"),!host.hasSuffix(".netlify.app"),!host.hasSuffix(".vercel.app") else{return nil}
        return endpoint.deletingLastPathComponent()
    }
    static func enabled(address:String?, defaults:UserDefaults = .standard) -> Bool {
        root(address) != nil && (defaults.object(forKey:enabledKey) == nil || defaults.bool(forKey:enabledKey))
    }
    static func board(_ address:String?, research:Bool=false) -> URL? {
        guard let address,let endpoint=Свежесть.endpoint(address),var c=URLComponents(url:endpoint.deletingLastPathComponent(),resolvingAgainstBaseURL:false) else{return nil}
        if research {c.fragment="research"};return c.url
    }
}

/// No redirects: a board cannot forward private ratings to another destination.
private final class CheckInTransport: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void) {completionHandler(nil)}
    func send(_ request:URLRequest,completion:@escaping(Data?,Int)->Void) {
        let config=URLSessionConfiguration.ephemeral;config.httpShouldSetCookies=false
        let session=URLSession(configuration:config,delegate:self,delegateQueue:nil)
        session.dataTask(with:request) {data,response,error in
            session.finishTasksAndInvalidate()
            DispatchQueue.main.async {completion(error == nil ? data:nil,(response as? HTTPURLResponse)?.statusCode ?? 0)}
        }.resume()
    }
}

/// One bounded union exchange, on open/save/minute tick. Failed exchanges keep every local record.
final class CheckInSync {
    struct Receipt: Codable {let acknowledged:[String:String];let checked:Date}
    typealias Transport=(URLRequest,@escaping(Data?,Int)->Void)->Void
    private let transport:Transport
    private let defaults:UserDefaults
    private let receiptURL:URL
    private var receipt:Receipt?
    private var source=""
    private var generation=0
    private var busy=false
    private var retryAfterSave=false
    private var lastAttempt:Date?
    private(set) var status="Check-ins · this Mac only"
    var onChange:((String)->Void)?
    init(receiptURL:URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Krest/check-in-sync-v1.json"),defaults:UserDefaults = .standard,transport:Transport? = nil) {
        self.receiptURL=receiptURL;self.defaults=defaults
        self.transport=transport ?? {request,done in CheckInTransport().send(request,completion:done)}
    }
    func pending(_ store:EventReviewStore) -> Int {
        store.records.filter{receipt?.acknowledged[$0.occurrence] != CheckInWire.fingerprint($0)}.count
    }
    private func publish(_ value:String) {status=value;onChange?(value)}
    func sync(address:String?,store:EventReviewStore,force:Bool=false) {
        let identity=BalanceRecord.source(address)
        if source != identity {
            generation += 1;source=identity;busy=false;retryAfterSave=false;lastAttempt=nil;receipt=nil
            // A receipt is scoped to the exact board; switching destinations never reuses an acknowledgement.
            if let bytes=try? Data(contentsOf:scopedReceipt),let value=try? JSONDecoder().decode(Receipt.self,from:bytes) {receipt=value}
        }
        guard CheckInConnection.enabled(address:address,defaults:defaults),let root=CheckInConnection.root(address) else {
            generation += 1;busy=false;retryAfterSave=false
            publish("Check-ins · this Mac only · sync off");return
        }
        guard store.issue == nil else {publish(store.issue!+" · sync paused");return}
        if busy {if force {retryAfterSave=true};return}
        if !force,let lastAttempt,Date().timeIntervalSince(lastAttempt)<45 {return}
        let sent=store.records
        guard sent.count <= 5000,sent.allSatisfy({$0.valid()}) else {publish("Check-in sync paused · invalid local records");return}
        var request=URLRequest(url:root.appendingPathComponent("check-ins/sync"));request.httpMethod="POST";request.timeoutInterval=8
        request.cachePolicy = .reloadIgnoringLocalCacheData;request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.httpBody=try? JSONSerialization.data(withJSONObject:["entries":sent.map(CheckInWire.object)])
        busy=true;lastAttempt=Date();let token=generation
        publish("Check-ins · private board + Mac · syncing · \(pending(store)) pending")
        transport(request) { [weak self] data,code in
            guard let self,self.generation == token else{return}
            self.busy=false
            if code == 200,let data,let canonical=CheckInWire.decode(data),
               sent.allSatisfy({local in canonical.contains{$0.occurrence == local.occurrence && $0.recorded.timeIntervalSince(local.recorded) >= -0.001}}),
               store.merge(canonical.filter {remote in
                   // The server resolves a timestamp tie. Preserve a local edit made since this request began.
                   guard let current=store.records.first(where:{$0.occurrence == remote.occurrence}),current.recorded == remote.recorded,
                         let previous=sent.first(where:{$0.occurrence == remote.occurrence}) else{return true}
                   return CheckInWire.fingerprint(current) == CheckInWire.fingerprint(previous)
               },preferIncomingOnTie:true) {
                let next=Receipt(acknowledged:Dictionary(uniqueKeysWithValues:canonical.map{($0.occurrence,CheckInWire.fingerprint($0))}),checked:Date())
                do {
                    try FileManager.default.createDirectory(at:self.scopedReceipt.deletingLastPathComponent(),withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
                    try JSONEncoder().encode(next).write(to:self.scopedReceipt,options:.atomic)
                    try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:self.scopedReceipt.path)
                    self.receipt=next
                    let f=DateFormatter();f.dateFormat="HH:mm"
                    self.publish("Check-ins · private board + Mac · checked \(f.string(from:next.checked)) · \(store.records.count) records · \(self.pending(store)) pending")
                }catch{self.publish("Check-ins saved · sync receipt unavailable · \(self.pending(store)) pending")}
            } else {
                let f=DateFormatter();f.dateFormat="dd MMM HH:mm"
                let last=self.receipt.map{" · last synced "+f.string(from:$0.checked)} ?? " · never synced"
                self.publish("Check-ins · sync unavailable\(code == 0 ? " (offline)":" (HTTP \(code) or invalid reply)") · \(self.pending(store)) pending · local records retained"+last)
            }
            if self.retryAfterSave {self.retryAfterSave=false;self.sync(address:address,store:store,force:true)}
        }
    }
    private var scopedReceipt:URL {receiptURL.deletingPathExtension().appendingPathExtension(source+".json")}
}
