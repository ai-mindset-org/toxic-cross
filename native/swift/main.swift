import AppKit
import Foundation
// Read-only diagnostic uses exactly the native URL and decoder, never prints block texts.
if CommandLine.arguments.contains("--check-source") {
    let address = ProcessInfo.processInfo.environment["KREST_URL"] ?? UserDefaults.standard.string(forKey: "KrestURL") ?? ""
    guard let url = Свежесть.endpoint(address) else { print("invalid address"); exit(2) }
    var request = URLRequest(url: url); request.timeoutInterval = 8
    request.cachePolicy = .reloadIgnoringLocalCacheData
    URLSession.shared.dataTask(with: request) { data, response, error in
        guard error == nil, let http = response as? HTTPURLResponse, http.statusCode == 200,
              let data, let day = День.разобрать(data, живой: true) else { print("source check failed"); exit(1) }
        print("HTTP 200; date=\(day.дата); built=\(day.собрано); blocks=\(day.лучи.reduce(0) { $0 + $1.штук }); sources=\(day.источники.count); x=\(day.x); y=\(day.y)")
        exit(0)
    }.resume()
    dispatchMain()
}
if CommandLine.arguments.contains("--check-calendar") {
    let frame=CalendarBridge.load(),now=Date(),events=frame.today(at:Date())
    print("source=\(frame.source); observed=\(frame.observed); fresh=\(frame.fresh(at:now)); today=\(events.count); current=\(events.filter{$0.phase(at:now)=="now"}.count); upcoming=\(events.filter{$0.phase(at:now)=="upcoming"}.count); earlier=\(events.filter{$0.phase(at:now)=="earlier"}.count)")
    exit(frame.observed ? 0:1)
}
if CommandLine.arguments.contains("--history-summary") {
    let store=BalanceHistory()
    let address=ProcessInfo.processInfo.environment["KREST_URL"] ?? UserDefaults.standard.string(forKey:"KrestURL")
    let points=store.points(sourceID:BalanceRecord.source(address),mode:address == nil ? "календарь":"борт")
    let f=ISO8601DateFormatter()
    print("records=\(points.count); days=\(Set(points.map{$0.day}).count); first=\(points.first.map{f.string(from:$0.collected)} ?? "none"); last=\(points.last.map{f.string(from:$0.collected)} ?? "none"); issue=\(store.issue ?? "none")")
    exit(store.issue == nil ? 0:1)
}
// Offscreen check of the shared shell wiring: pin, theme, the family key table and the recorder. Nothing is
// shown, stored or registered; the walk reads a scratch defaults suite and a fixed sibling reader.
if CommandLine.arguments.contains("--check-shell") {
    var failures:[String]=[]
    func need(_ ok:Bool,_ what:String){print((ok ? "PASS ":"FAIL ")+what);if !ok{failures.append(what)}}
    let scratch=UserDefaults(suiteName:"org.aimindset.krest.bar.check")!;scratch.removePersistentDomain(forName:"org.aimindset.krest.bar.check")
    scratch.set(true,forKey:Delegate.pinKey);need(Delegate.loadPin(scratch)==true,"pin: migration preserves an explicit saved choice")
    scratch.set(true,forKey:Delegate.pinKey);need(Delegate.loadPin(scratch)==true,"pin: a later choice survives a restart")
    need(AIMThemePolicy.key(bundle:"org.aimindset.krest.bar")=="org.aimindset.krest.bar.theme","theme: one key form, <bundle id>.theme")
    need(AIMThemePolicy.resolve(nil) == .light && AIMThemePolicy.resolve("dark") == .dark && AIMThemePolicy.resolve("noise") == .light,"theme: white by default, dark only when stored")
    need(FamilyHotkeys.signature==FamilyHotkeys.sharedSignature,"keys: the family table matches the shared signature")
    need(FamilyHotkeys.familyDefaults.count==6 && FamilyHotkeys.printedRows.count==6,"keys: six products in the family table")
    let store=FamilyHotkeyStore(owner:FamilyHotkeys.krest,fallback:Delegate.hotkeyStore.fallback,bundle:"org.aimindset.krest.bar.check",defaults:scratch)
    need(store.current?.display=="⌥⌘X","keys: krest ships ⌥⌘X")
    let field=FamilyHotkeyField(store:store);field.reader = .absent;var line=""
    field.onLine={line=$0}
    field.take(keyCode:46,flags:[.option,.command],characters:"m");need(line.contains("taken by MEM PRISM") && store.current?.display=="⌥⌘X","keys: ⌥⌘M is refused by name and the old value stays")
    field.take(keyCode:32,flags:[.option,.command],characters:"u");need(line.contains("taken by Murmur AIM"),"keys: ⌥⌘U belongs to Murmur AIM")
    field.take(keyCode:7,flags:[.command],characters:"x");need(line.contains("two modifiers"),"keys: one modifier is refused")
    field.take(keyCode:7,flags:[.control,.option],characters:"x");need(store.current?.display=="⌃⌥X","keys: a free pair is stored")
    field.take(keyCode:51,flags:[],characters:nil);need(store.current==nil,"keys: delete clears")
    scratch.removePersistentDomain(forName:"org.aimindset.krest.bar.check")
    print(failures.isEmpty ? "PASS: krest shell check, \(FamilyHotkeys.printedRows.joined(separator:" · "))":"FAIL: \(failures.count)");exit(failures.isEmpty ? 0:1)
}
if let index=CommandLine.arguments.firstIndex(of:"--render-fixture"),CommandLine.arguments.count>index+1 {
    let app=NSApplication.shared;app.setActivationPolicy(.prohibited);UI.registerFonts()
    // `--theme dark|light` renders one theme without storing it; the default reads the saved choice.
    let theme=CommandLine.arguments.firstIndex(of:"--theme").flatMap{CommandLine.arguments.count>$0+1 ? AIMThemePolicy.resolve(CommandLine.arguments[$0+1]) : nil} ?? AIMThemePolicy.load()
    AIMThemePolicy.apply(theme)
    let data=try Data(contentsOf:Bundle.main.url(forResource:"демо",withExtension:"json")!)
    let day=День.разобрать(data,живой:false)!
    let panel=ПанельView(frame:NSRect(x:0,y:0,width:ПанельView.width,height:ПанельView.height))
    panel.hotkeyStore=Delegate.hotkeyStore;panel.themeButton.setMode(theme)
    panel.показать(day);if CommandLine.arguments.contains("--settings") {panel.select("settings")};panel.соединение("Fictional example · no personal sources connected",loading:false)
    if CommandLine.arguments.contains("--day") {
        let now=Date(),start=Calendar.current.startOfDay(for:now),end=Calendar.current.date(byAdding:.day,value:1,to:start)!
        let events=[CalendarMoment(id:"demo-current",title:"Fictional design review",start:now.addingTimeInterval(-600),end:now.addingTimeInterval(1200),allDay:false,declined:false,url:nil,source:"Fictional fixture"),CalendarMoment(id:"demo-next",title:"Fictional project check-in",start:now.addingTimeInterval(3600),end:now.addingTimeInterval(5400),allDay:false,declined:false,url:nil,source:"Fictional fixture")]
        panel.calendar(CalendarFrame(events:events,source:"Fictional calendar · demo only",fetched:now,start:start,end:end,issue:nil));panel.select("day")
    }
    let window=NSWindow(contentRect:panel.frame,styleMask:.borderless,backing:.buffered,defer:false)
    window.contentView=panel;panel.layoutSubtreeIfNeeded()
    let bitmap=panel.bitmapImageRepForCachingDisplay(in:panel.bounds)!
    panel.cacheDisplay(in:panel.bounds,to:bitmap)
    try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[index+1]))
    print("fixture rendered; font=\(UI.mono(12).fontName); size=\(panel.bounds)");exit(0)
}
let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.run()
