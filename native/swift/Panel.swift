import AppKit

final class KrestPopUp: NSPopUpButton {
    var changed: ((Int) -> Void)?
    init(items: [String], selected: Int = 0, width: CGFloat = 220, tip: String, changed: @escaping (Int) -> Void) {
        super.init(frame: .zero, pullsDown: false)
        addItems(withTitles: items); selectItem(at: selected); self.changed = changed
        target = self; action = #selector(pick); font = UI.mono(11); toolTip = tip
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        heightAnchor.constraint(equalToConstant: 28).isActive = true
        bezelStyle = .rounded
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func pick() { changed?(indexOfSelectedItem) }
}

/// Actual coordinates, same horizontal/vertical meanings as the menu glyph and web field.
final class BalanceView: NSView {
    var x = 0.0, y = 0.0
    override var isFlipped: Bool { true }
    init(x: Double, y: Double) {
        self.x = x; self.y = y; super.init(frame: NSRect(x: 0, y: 0, width: 488, height: 142))
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 488).isActive = true
        heightAnchor.constraint(equalToConstant: 142).isActive = true
        setAccessibilityElement(true); setAccessibilityRole(.image)
        setAccessibilityLabel(String(format: "Krest: future/past x %.2f, resources/obligations y %.2f", x, y))
        toolTip = String(format: "where the day pulls: x %+.2f (past ← → future), y %+.2f (obligations ↑ ↓ resources)", x, y)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ rect: NSRect) {
        let cx = bounds.midX, cy = bounds.midY, a: CGFloat = 47
        UI.gray200.setStroke(); let p = NSBezierPath(); p.lineWidth = 1
        p.move(to: NSPoint(x: cx-a, y: cy)); p.line(to: NSPoint(x: cx+a, y: cy))
        p.move(to: NSPoint(x: cx, y: cy-a)); p.line(to: NSPoint(x: cx, y: cy+a)); p.stroke()
        func text(_ s: String, _ at: NSPoint) { (s as NSString).draw(at: at, withAttributes: [.font:UI.mono(10), .foregroundColor:UI.gray600]) }
        text("obligations", NSPoint(x:cx-43,y:0)); text("resources",NSPoint(x:cx-23,y:126))
        text("past",NSPoint(x:cx-118,y:cy-6));text("future",NSPoint(x:cx+66,y:cy-6))
        UI.red.setFill(); NSBezierPath(ovalIn:NSRect(x:cx+CGFloat(x)*a-4,y:cy+CGFloat(y)*a-4,width:8,height:8)).fill()
        UI.ink.setStroke(); NSBezierPath(ovalIn:NSRect(x:cx-2,y:cy-2,width:4,height:4)).stroke()
    }
}

final class HistoryChart: NSView {
    let records: [BalanceRecord]
    let start: Date, end: Date
    let selected: String?
    var onSelect: ((String) -> Void)?
    override var isFlipped: Bool { true }
    init(records: [BalanceRecord], start: Date, end: Date, selected: String?, onSelect: @escaping (String)->Void) {
        self.records=records;self.start=start;self.end=end;self.selected=selected;self.onSelect=onSelect
        super.init(frame:NSRect(x:0,y:0,width:488,height:156));translatesAutoresizingMaskIntoConstraints=false
        widthAnchor.constraint(equalToConstant:488).isActive=true;heightAnchor.constraint(equalToConstant:156).isActive=true
        setAccessibilityElement(true);setAccessibilityRole(.image)
        setAccessibilityLabel("Balance over time, \(records.count) saved observations. Select a date in the list below.")
        toolTip = "click a point to open that saved observation · solid line y, dashed line x"
    }
    required init?(coder:NSCoder){fatalError()}
    private func px(_ r:BalanceRecord)->CGFloat { 30+CGFloat(r.collected.timeIntervalSince(start)/max(1,end.timeIntervalSince(start)))*448 }
    override func draw(_ rect:NSRect) {
        func text(_ s:String,_ x:CGFloat,_ y:CGFloat){(s as NSString).draw(at:NSPoint(x:x,y:y),withAttributes:[.font:UI.mono(10),.foregroundColor:UI.gray600])}
        for v in [-1.0,0,1] {
            let y=66-CGFloat(v)*48;UI.gray200.setStroke();let line=NSBezierPath();line.move(to:NSPoint(x:30,y:y));line.line(to:NSPoint(x:478,y:y));line.stroke();text(String(format:"%+.0f",v),0,y-6)
        }
        for vertical in [true,false] {
            (vertical ? UI.ink : UI.gray600).setStroke();let line=NSBezierPath();line.lineWidth=1.5
            if !vertical { line.setLineDash([4,3],count:2,phase:0) }
            var previous:BalanceRecord?
            for r in records {
                let point=NSPoint(x:px(r),y:66-CGFloat(vertical ? r.y:r.x)*48)
                if let old=previous, HistoryComparison.connects(old,r) {line.line(to:point)}else{line.move(to:point)}
                previous=r
            }
            line.stroke()
            for r in records {
                (r.id==selected ? UI.red : vertical ? UI.ink:UI.gray600).setFill()
                let radius:CGFloat=r.id==selected ? 3.5:2
                NSBezierPath(ovalIn:NSRect(x:px(r)-radius,y:66-CGFloat(vertical ? r.y:r.x)*48-radius,width:radius*2,height:radius*2)).fill()
            }
        }
        let f=DateFormatter();f.dateFormat="dd.MM";text(f.string(from:start),30,125);text(f.string(from:end),439,125)
        text("solid: y · dashed: x · gaps: no observation",30,141)
    }
    override func mouseDown(with event:NSEvent) {
        let x=convert(event.locationInWindow,from:nil).x
        if let r=records.min(by:{abs(px($0)-x)<abs(px($1)-x)}),abs(px(r)-x)<18 {onSelect?(r.id)}
    }
}

final class HistoryDocument: NSView { override var isFlipped: Bool { true } }

final class ПанельView: NSView {
    static let width:CGFloat=520, height:CGFloat=690, content:CGFloat=488
    private var day:День?
    private var points:[BalanceRecord]=[]
    private var selectedID:String?
    private var range=30
    private var connection="Connecting…",archiveStatus="Archive not checked yet"
    private var loading=false
    private let scroll=NSScrollView()
    private var bodyStack=NSStackView()
    private(set) var navigation=KrestNavigation()
    private var active:String {navigation.current}
    private var keyField:FamilyHotkeyField?
    private var lastRendered=""
    private var frameData:CalendarFrame?
    private var showEarlier=true
    private var showBoardDetails=false
    private var checkInEvent:CalendarMoment?
    private var reviewFeeling=0,reviewEnergy=0
    private var reframeField:NSTextField?
    private var reframePreview=false
    private var feedback=""
    var reviews:EventReviewStore?
    var reviewSyncStatus="Check-ins · this Mac only"
    var syncReviews:(()->Void)?
    var toggleReviewSync:((Bool)->Void)?
    var reviewSyncEnabled=false
    var openResearch:(()->Void)?
    var saveReview:((CalendarMoment,Int,Int,String)->Bool)?
    var toggleReminders:((Bool)->Void)?
    var saveBoard:((String)->Bool)?
    var boardAddress=""
    var bridgeStatus="Calendar sharing is off"
    var noticeStatus="Off · check-ins stay in the app"
    private var header:AIMAppHeader!
    private var tabs:AIMTabStrip!
    private var footer:AIMFooterLine!
    let pin=AIMPinButton()
    /// Rule 53: the footer control; the delegate stores the mode and applies it to the process.
    let themeButton=AIMThemeButton(mode:AIMThemePolicy.load())
    var onTheme:((AIMThemePolicy.Mode)->Void)?
    var hotkeyStore:FamilyHotkeyStore?
    var onHotkey:((FamilyHotkey?)->Void)?
    private var hotkeyLine=""
    private var hotkeyAvailable=true
    private var keysLine:String { (hotkeyStore?.current.map{$0.display+" · "} ?? "")+"1–4 views · ⌘K actions" }
    var change="Waiting for a second observed snapshot to compare."
    var открытьБорт:(()->Void)?
    var обновить:(()->Void)?
    var syncHistory:(()->Void)?
    var close:(()->Void)?
    var onPin:((Bool)->Void)?
    var setMenuMode:((String)->Void)?
    var openCalendar:(()->Void)?
    var reflect:((String,String)->Void)?
    var menuMode="mark"
    override init(frame:NSRect) {
        super.init(frame:frame);appearance=NSApp.effectiveAppearance;wantsLayer=true;layer?.backgroundColor=AIMThemePolicy.resolvedCGColor(UI.white,appearance:effectiveAppearance)
        let info=Bundle.main.infoDictionary,version=(info?["CFBundleShortVersionString"] as? String ?? "2.1.0")+" · build "+(info?["CFBundleVersion"] as? String ?? "11")
        header=AIMAppHeader(mark:.krest,name:"Krest",status:"Day balance",version:version,width:Self.content,onSettings:{[weak self] in self?.select("settings")},pin:pin,onClose:{[weak self] in self?.close?()})
        header.closeButton?.toolTip="close the panel · esc or ⌘W"
        let voxel=AIMVoxelView(model:AIMVoxelModels.krest,frame:NSRect(x:0,y:0,width:40,height:40))
        voxel.setAccessibilityLabel("Krest mark");header.markView.setAccessibilityLabel("Krest mark");voxel.wantsLayer=true;voxel.layer?.backgroundColor=AIMThemePolicy.resolvedCGColor(AIMAppShellStyle.plate,appearance:effectiveAppearance);header.markView.addSubview(voxel)
        voxel.toolTip="krest · live character · click: scatter and assemble"
        pin.onChange={[weak self] value in self?.onPin?(value);self?.render()}
        themeButton.onChange={[weak self] mode in self?.onTheme?(mode)}
        tabs=AIMTabStrip(tabs:[.init(id:"now",title:"balance",hint:"balance now: the dot, the four arms and their sources"),.init(id:"day",title:"day",hint:"today's calls, the calendar load and the board observations"),.init(id:"history",title:"history",hint:"saved observations over 7, 30, 90 days or a year"),.init(id:"settings",title:"settings",hint:"menu bar mode, pin, theme, the global key and data notes")],selected:"now",width:Self.content,tabWidth:112,onSelect:{[weak self] id in self?.select(id)})
        footer=AIMFooterLine(keys:"1–4 views · ⌘K actions",esc:"esc close",status:"",width:Self.content,theme:themeButton,apps:{NSWorkspace.shared.open(URL(string:"https://apps.aimindset.org/")!)})
        scroll.drawsBackground=false;scroll.hasVerticalScroller=true;scroll.autohidesScrollers=true;scroll.translatesAutoresizingMaskIntoConstraints=false
        let root=NSStackView(views:[header,tabs,scroll,footer]);root.orientation = .vertical;root.alignment = .leading;root.spacing=12;root.translatesAutoresizingMaskIntoConstraints=false;addSubview(root)
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo:leadingAnchor,constant:16),root.trailingAnchor.constraint(equalTo:trailingAnchor,constant:-16),root.topAnchor.constraint(equalTo:topAnchor,constant:16),root.bottomAnchor.constraint(equalTo:bottomAnchor,constant:-16),scroll.widthAnchor.constraint(equalToConstant:Self.content),scroll.heightAnchor.constraint(greaterThanOrEqualToConstant:480)])
        render()
    }
    required init?(coder:NSCoder){fatalError()}
    func select(_ id:String){
        guard ["now","day","history","settings"].contains(id) else{return}
        window?.makeFirstResponder(nil)
        navigation.select(id);tabs.select(id);render()
    }
    /// First Escape belongs to a recorder; the next returns from Settings.
    func handlePanelKey(_ event:NSEvent)->Bool {
        if let field=keyField,field.recording {
            field.take(keyCode:event.keyCode,flags:event.modifierFlags,characters:event.charactersIgnoringModifiers)
            return true
        }
        if event.keyCode == 53,checkInEvent != nil,navigation.current == "day" {
            checkInEvent=nil;window?.makeFirstResponder(nil);render();return true
        }
        if event.keyCode == 53,navigation.current == "settings" {
            select(navigation.previous);return true
        }
        let mods=event.modifierFlags.intersection([.command,.control,.option,.shift])
        if mods == .command,(event.keyCode == 43 || event.charactersIgnoringModifiers == ",") {
            select("settings");return true
        }
        return false
    }
    /// Rule 53: the process appearance changed; layer colours are read again and the body is rebuilt.
    func themeChanged(_ mode:AIMThemePolicy.Mode = AIMThemePolicy.load()){
        appearance=AIMThemePolicy.appearance(mode)
        layer?.backgroundColor=AIMThemePolicy.resolvedCGColor(UI.white,appearance:effectiveAppearance);themeButton.setMode(mode);render()
        func mark(_ v:NSView){v.needsDisplay=true;v.subviews.forEach(mark)};mark(self)
    }
    func hotkeyState(combo:FamilyHotkey?,available:Bool){
        hotkeyAvailable=available;footer.setKeys(keysLine)
        if !available,let combo {hotkeyLine="\(combo.display) is held by another app; record another one"}
        if active=="settings"{render()}
    }
    func соединение(_ text:String,loading:Bool){connection=text;self.loading=loading;if active=="now"{render()}}
    func показать(_ d:День?){day=d;if active != "settings" {render()}}
    func history(_ data:[BalanceRecord],status:String){points=data;archiveStatus=status;if active=="history"{render()}}
    func calendar(_ data:CalendarFrame){frameData=data;if active=="day" && checkInEvent == nil{render()}}
    func checkInReceipt(_ status:String,enabled:Bool) {
        reviewSyncStatus=status;reviewSyncEnabled=enabled
        if ["day","history"].contains(active),checkInEvent == nil {render()}
        refreshPreferences()
    }
    func refreshPreferences(){if active=="settings",keyField?.recording != true,!(window?.firstResponder is NSTextView){render()}}
    private func label(_ text:String,size:CGFloat=11,muted:Bool=false)->NSTextField {
        let l=NSTextField(wrappingLabelWithString:text);l.font=UI.mono(size);l.textColor=muted ? UI.gray600:UI.ink
        l.translatesAutoresizingMaskIntoConstraints=false;l.widthAnchor.constraint(equalToConstant:Self.content-14).isActive=true;return l
    }
    private func add(_ v:NSView){bodyStack.addArrangedSubview(v)}
    private func button(_ text:String,width:CGFloat=140,tip:String,_ action:@escaping()->Void)->AIMShellButton{let b=AIMShellButton(text,width:width,action:action);b.toolTip=tip;return b}
    private func row(_ views:[NSView])->NSStackView{let r=NSStackView(views:views);r.spacing=8;r.alignment = .centerY;return r}
    private func rule(){let v=NSView();v.wantsLayer=true;v.layer?.backgroundColor=AIMThemePolicy.resolvedCGColor(UI.gray200,appearance:effectiveAppearance);v.translatesAutoresizingMaskIntoConstraints=false;v.widthAnchor.constraint(equalToConstant:Self.content-14).isActive=true;v.heightAnchor.constraint(equalToConstant:1).isActive=true;add(v)}
    private func render() {
        let mode:AIMThemePolicy.Mode=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? .dark:.light
        AIMThemePolicy.withAppearance(mode) {renderBody()}
    }
    private func renderBody() {
        if let field=keyField,field.recording {field.take(keyCode:53,flags:[],characters:nil)};keyField=nil
        let offset=lastRendered == active ? scroll.contentView.bounds.origin : NSPoint.zero
        lastRendered=active
        header.setStatus((day?.режим.title ?? "Waiting for source")+(pin.pinned ? " · pinned open":""))
        bodyStack=NSStackView();bodyStack.orientation = .vertical;bodyStack.alignment = .leading;bodyStack.spacing=12;bodyStack.translatesAutoresizingMaskIntoConstraints=false
        let doc=HistoryDocument();doc.translatesAutoresizingMaskIntoConstraints=false;doc.addSubview(bodyStack);scroll.documentView=doc
        NSLayoutConstraint.activate([doc.widthAnchor.constraint(equalTo:scroll.widthAnchor),bodyStack.topAnchor.constraint(equalTo:doc.topAnchor),bodyStack.leadingAnchor.constraint(equalTo:doc.leadingAnchor),bodyStack.trailingAnchor.constraint(equalTo:doc.trailingAnchor),bodyStack.bottomAnchor.constraint(equalTo:doc.bottomAnchor,constant:-8)])
        if active=="now"{now()}else if active=="day"{dayBody()}else if active=="history"{historyBody()}else{settings()}
        footer.setStatus(loading ? "checking" : pin.pinned ? "pinned":"");footer.setKeys(keysLine);footer.escLabel.stringValue=active == "settings" ? "esc back":"esc close"
        layoutSubtreeIfNeeded();scroll.contentView.scroll(to:NSPoint(x:0,y:min(offset.y,max(0,doc.bounds.height-scroll.contentView.bounds.height))))
    }
    private func now() {
        guard let d=day else {add(label("Waiting for a snapshot",size:18));add(label(connection,muted:true));add(button("refresh",tip:"read the board or the calendar again now · ⌘R"){[weak self] in self?.обновить?()});return}
        add(label(String(format:"Balance %.2f · %@",d.перекос,d.куда),size:16))
        add(label(d.живой ? Свежесть.описание(d.собрано) : "Fixed fictional example · "+d.дата,muted:true))
        add(BalanceView(x:d.x,y:d.y))
        add(label("Filled dot: current balance. Small ring: neutral centre. Up = obligations, down = resources; left = past, right = future.",size:10,muted:true))
        if let summary=reviews?.summary(on:Date()) {
            add(label(String(format:"Your check-ins · %d events · feeling %+.1f · energy %+.1f",summary.count,summary.feeling,summary.energy),size:11))
            add(label("Your own −2…+2 ratings. Unrated events stay unknown. These ratings remain separate from the source balance.",size:10,muted:true))
        }
        let maxWeight=max(1,d.лучи.map{abs($0.сумма)}.max() ?? 1)
        for arm in d.лучи {
            add(label(String(format:"%@  %.1f · %d blocks",Copy.name(arm.имя),arm.сумма,arm.штук)))
            let bar=NSView();bar.wantsLayer=true;bar.layer?.backgroundColor=AIMThemePolicy.resolvedCGColor(UI.gray200,appearance:effectiveAppearance);bar.translatesAutoresizingMaskIntoConstraints=false
            bar.widthAnchor.constraint(equalToConstant:Self.content-14).isActive=true;bar.heightAnchor.constraint(equalToConstant:3).isActive=true
            let fill=NSView(frame:NSRect(x:0,y:0,width:(Self.content-14)*abs(arm.сумма)/maxWeight,height:3));fill.wantsLayer=true;fill.layer?.backgroundColor=AIMThemePolicy.resolvedCGColor(arm.сумма<0 ? UI.red:UI.ink,appearance:effectiveAppearance);bar.addSubview(fill);add(bar)
        }
        add(label(d.живой ? change : "Fixed examples are never saved to history.",size:10,muted:true));add(label(connection,size:10,muted:true))
        let refresh=button(loading ? "checking…":"refresh",tip:"read the board or the calendar again now · ⌘R"){[weak self] in self?.обновить?()};refresh.isEnabled = !loading
        var actions:[NSView]=[refresh,button("day & calendar",tip:"switch to today's calls and calendar load · key 2"){[weak self] in self?.select("day")}]
        if d.режим == .борт {actions.append(button("open board",tip:"open the private board in the browser"){[weak self] in self?.открытьБорт?()})};add(row(actions))
        if !boardAddress.isEmpty {add(button("open research board",width:240,tip:"open the wide research board in your browser · #research"){[weak self] in self?.openResearch?()})}
        rule();add(label("Reframe the day",size:16))
        add(label("A deliberate change of perspective. Review the four questions, choose a concrete next step, then check whether it helped.",size:11,muted:true))
        add(button(reframePreview ? "return to observed":"preview a reframe",width:210,tip:"temporary illustration; the original observations and obligations stay intact"){[weak self] in self?.reframePreview.toggle();self?.render()})
        if reframePreview {
            add(BalanceView(x:d.x*0.25,y:d.y*0.25))
            add(label("ILLUSTRATION · weights at 25%. This is a visual thought experiment, with no validated psychological meaning.",size:10,muted:true))
            for question in ["Obligations · What is truly mine, and what can I renegotiate?","Past · What evidence or previous skill can support me?","Resources · What support is available for one next step?","Future · What other outcome is plausible, and what can I influence?"] {add(label(question))}
        }
        rule();add(label("Sources",size:16))
        for source in d.источники {
            add(label(Copy.name(source.имя)+" · "+source.displayStatus(),size:10,muted:true))
            if !source.note.isEmpty {add(label(source.note,size:10,muted:true))}
            if !source.timingReceipt.isEmpty {add(label(source.timingReceipt,size:10,muted:true))}
        }
    }
    private func dayBody() {
        if let event=checkInEvent {checkInBody(event);return}
        let now=Date(),date=DateFormatter();date.locale=Locale(identifier:"en_US_POSIX");date.dateFormat="EEE d MMM"
        add(label(date.string(from:now)+" · "+TimeZone.current.abbreviation()!,size:18))
        add(label(reviewSyncStatus,size:10,muted:true))
        if reviewSyncEnabled {add(button("sync check-ins",width:200,tip:"exchange personal ratings with the configured private board; calendar sources are unchanged"){[weak self] in self?.syncReviews?()})}
        if !boardAddress.isEmpty {add(button("open research board",width:240,tip:"open the wide research board · #research"){[weak self] in self?.openResearch?()})}
        add(row([button("open calendar",width:164,tip:"open Calendar Control, or macOS Calendar when it is not installed"){[weak self] in self?.openCalendar?()},button("refresh sources",width:164,tip:"read the calendar snapshot and the board again; Google is not asked"){[weak self] in self?.обновить?()}]))
        if let frame=frameData {
            add(label(frame.receipt(at:now),size:10,muted:true))
            let events=frame.today(at:now),earlier=events.filter{$0.end<=now},current=events.filter{$0.start<=now && $0.end>now && !$0.allDay && !$0.declined},upcoming=events.filter{$0.start>now && !$0.allDay && !$0.declined}
            if frame.observed || !events.isEmpty {
                add(label("\(events.count) today · \(current.count) now · \(upcoming.count) upcoming · \(earlier.count) earlier",size:11))
                if frame.fresh(at:now) {
                    let p=frame.pressure(at:now)
                    add(label(String(format:"%.1f pts remaining · %.1f h unscheduled until 19:00",p.remaining,p.freeHours),size:11,muted:true))
                }else{add(label("Snapshot is stale or incomplete. Event times are shown as recorded; the current calendar-load estimate is unavailable.",muted:true))}
                if let d=day,d.режим == .борт {
                    if d.calendarBlockCount==0 && !events.isEmpty {add(label("Calendar mismatch: these events are missing from the board balance.",size:11))}
                }
                rule()
                for e in current+upcoming+events.filter({$0.allDay}) {eventRow(e,now:now)}
                if current.isEmpty && upcoming.isEmpty {add(label("No upcoming timed events recorded for today.",muted:true))}
                if let next=frame.events.filter({$0.start>now && !Calendar.current.isDate($0.start,inSameDayAs:now) && !$0.declined && !$0.allDay}).sorted(by:{$0.start<$1.start}).first {
                    add(label("Next recorded day",size:16));eventRow(next,now:now)
                }
                if !earlier.isEmpty {
                    add(button(showEarlier ? "hide earlier":"show \(earlier.count) earlier",width:200,tip:showEarlier ? "fold the events that already ended":"list the events that already ended today"){[weak self] in self?.showEarlier.toggle();self?.render()})
                    if showEarlier {for e in earlier.reversed(){eventRow(e,now:now)}}
                }
            }else {add(label(frame.issue ?? "No calendar observed",muted:true))}
        }else {add(label("Reading calendar source…",muted:true))}
        if day?.режим == .борт {
            add(button(showBoardDetails ? "hide board observations":"show board observations",width:260,tip:"source receipts and aggregate commitment records; separate from your ratings"){[weak self] in self?.showBoardDetails.toggle();self?.render()})
        }
        if let d=day,d.режим == .борт,showBoardDetails {
            rule();add(label("Board observations",size:16));add(label(Свежесть.описание(d.собрано),size:10,muted:true))
            add(label("\(d.promiseBlockCount) promise blocks in the board snapshot. These are weighted source records, not a verified promise count for an individual call.",size:10,muted:true))
            if !d.calendarItems.isEmpty {
                add(label("Calendar events included by the board",size:11))
                for item in d.calendarItems.prefix(5) {add(label((item["time"] ?? "")+" · "+(item["title"] ?? ""),size:10,muted:true))}
            }
            if let note=d.focusNotice,!note.isEmpty {add(label("Focus source receipt (original): "+note,size:10,muted:true))}
            if d.facts.isEmpty {add(label("No recent event observations in this board snapshot.",muted:true))}
            for f in d.facts.suffix(5).reversed() {
                add(label(f.time+" · "+f.title));if !f.detail.isEmpty{add(label(f.detail,size:10,muted:true))}
                add(button("reflect…",width:120,tip:"open the board form for this event; nothing is sent until you submit it"){[weak self] in self?.reflect?(f.title,d.дата)})
            }
            if let note=d.источники.first(where:{$0.имя=="календарь"})?.note,!note.isEmpty {add(label("Board calendar receipt (original): "+note,size:10,muted:true))}
        }
        add(label("A check-in records your experience. Ending an event leaves its outcome unverified.",size:10,muted:true))
    }
    private func eventRow(_ e:CalendarMoment,now:Date) {
        let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX");f.dateFormat="EEE HH:mm"
        let isNew=e.addedAt.map{now.timeIntervalSince($0)>=0 && now.timeIntervalSince($0)<3600} ?? false
        let heading=label((isNew ? "NEW · ":"")+e.phase(at:now).uppercased()+" · "+f.string(from:e.start)+" · "+e.title,size:12)
        if e.phase(at:now)=="now" {let edge=NSView();edge.wantsLayer=true;edge.layer?.backgroundColor=AIMThemePolicy.resolvedCGColor(UI.red,appearance:effectiveAppearance);edge.translatesAutoresizingMaskIntoConstraints=false;edge.widthAnchor.constraint(equalToConstant:3).isActive=true;edge.heightAnchor.constraint(equalToConstant:24).isActive=true;add(row([edge,heading]))}else{add(heading)}
        f.dateFormat="HH:mm";add(label("until "+f.string(from:e.end)+" · "+e.source,size:10,muted:true))
        if let review=reviews?.review(e) {add(label("YOUR CHECK-IN · \(EventReview.feelings[review.feeling+2]) · energy \(EventReview.energies[review.energy+2])",size:10,muted:true))}
        var actions:[NSView]=[button(reviews?.review(e) == nil ? "check in":"edit check-in",width:150,tip:"rate feeling and energy; saved on this Mac, with optional private-board sync in Settings"){[weak self] in
            guard let self else{return};let previous=self.reviews?.review(e);self.reviewFeeling=previous?.feeling ?? 0;self.reviewEnergy=previous?.energy ?? 0;self.checkInEvent=e;self.feedback="";self.render()
        }]
        if let url=e.url {actions.append(button("open event link",width:164,tip:"open the event's existing link"){NSWorkspace.shared.open(url)})}
        add(row(actions));rule()
    }
    private func checkInBody(_ event:CalendarMoment) {
        add(button("← back to day",width:160,tip:"return without saving"){[weak self] in self?.checkInEvent=nil;self?.render()})
        add(label(event.title,size:17));add(label(event.phase(at:Date()).uppercased()+" · your experience at this moment",size:10,muted:true))
        add(label("How does it feel?",size:16))
        add(KrestPopUp(items:Array(-2...2).map{"\($0 > 0 ? "+":"")\($0) · "+EventReview.feelings[$0+2]},selected:reviewFeeling+2,width:360,tip:"your own five-point feeling scale"){[weak self] in self?.reviewFeeling=$0-2})
        add(label("What happened to your energy?",size:16))
        add(KrestPopUp(items:Array(-2...2).map{"\($0 > 0 ? "+":"")\($0) · "+EventReview.energies[$0+2]},selected:reviewEnergy+2,width:360,tip:"energy compared with just before the event"){[weak self] in self?.reviewEnergy=$0-2})
        add(label("A different perspective or one next step",size:16))
        let field=NSTextField(string:reviews?.review(event)?.reframe ?? "");field.font=UI.mono(12);field.placeholderString="Optional · one sentence, up to 280 characters";field.translatesAutoresizingMaskIntoConstraints=false;field.widthAnchor.constraint(equalToConstant:Self.content-14).isActive=true;field.heightAnchor.constraint(equalToConstant:52).isActive=true;field.setAccessibilityLabel("Private reframe or next step");reframeField=field;add(field)
        add(label(reviewSyncEnabled ? "Saved on this Mac, then synced with your configured private board. Ratings, times and your optional sentence are shared. Event titles and URLs are excluded." : "Saved on this Mac in a private check-in file. Enable ratings sync in Settings to share with your private board. Event titles and URLs are excluded.",size:10,muted:true))
        add(row([button("save check-in",width:180,tip:"store your explicit rating and optional sentence locally"){[weak self] in
            guard let self else{return};let text=String(self.reframeField?.stringValue.prefix(280) ?? "");self.window?.makeFirstResponder(nil)
            if self.saveReview?(event,self.reviewFeeling,self.reviewEnergy,text) == true {self.checkInEvent=nil;self.feedback="Check-in saved on this Mac"}else{self.feedback="Could not save. Your existing file is preserved."};self.render()
        },button("skip",width:100,tip:"return with no recorded rating"){[weak self] in self?.checkInEvent=nil;self?.render()}]))
        if !feedback.isEmpty {add(label(feedback))}
    }
    private func historyBody() {
        add(label(reviewSyncStatus,size:10,muted:true))
        if reviewSyncEnabled {add(button("sync check-ins",width:200,tip:"check for browser check-ins and send pending local ratings"){[weak self] in self?.syncReviews?()})}
        if let records=reviews?.records,!records.isEmpty {
            add(label("Your recent check-ins",size:17))
            let stamp=DateFormatter();stamp.dateFormat="dd MMM HH:mm"
            for review in records.prefix(8) {
                add(label(stamp.string(from:review.start)+" · "+EventReview.feelings[review.feeling+2]+" · energy "+EventReview.energies[review.energy+2],size:11))
                if !review.reframe.isEmpty {add(label(review.reframe,size:10,muted:true))}
            }
            add(label("Your recorded reports. Missing events have no inferred rating. Event titles are excluded from this journal.",size:10,muted:true));rule()
        }
        let end=Date(),start=Calendar.current.date(byAdding:.day,value:-range,to:end)!
        let visible=points.filter{$0.collected>=start && $0.collected<=end}
        add(row([KrestPopUp(items:["7 days","30 days","90 days","year"],selected:[7,30,90,365].firstIndex(of:range) ?? 1,width:130,tip:"how far back the chart and the lists reach"){[weak self] i in self?.range=[7,30,90,365][i];self?.render()},button("check archive",width:170,tip:"read the board archive again and add the observations it holds"){[weak self] in self?.syncHistory?()}]))
        add(label("\(visible.count) snapshots · \(Set(visible.map{$0.day}).count) observed days",size:16));add(label(archiveStatus,size:10,muted:true))
        guard !visible.isEmpty else {add(label("No snapshots in this period. Successful source checks add observations; fictional examples are never saved.",muted:true));return}
        let record=visible.first{$0.id==selectedID} ?? visible.last!
        add(HistoryChart(records:visible,start:start,end:end,selected:record.id){[weak self] id in self?.selectedID=id;self?.render()})
        add(label("y: resources (+) / obligations (−) · x: future (+) / past (−)",size:10,muted:true))
        let dates=Array(Set(visible.map{$0.day})).sorted().reversed().map{$0}
        add(KrestPopUp(items:dates,selected:dates.firstIndex(of:record.day) ?? 0,width:180,tip:"pick an observed day"){[weak self] i in self?.selectedID=visible.last{$0.day==dates[i]}?.id;self?.render()})
        let samples=visible.filter{$0.day==record.day};let f=DateFormatter();f.dateFormat="HH:mm:ss"
        add(KrestPopUp(items:samples.map{f.string(from:$0.collected)+" · "+Copy.name($0.origin)},selected:samples.firstIndex{$0.id==record.id} ?? 0,width:340,tip:"pick one capture of that day: time and source"){[weak self] i in self?.selectedID=samples[i].id;self?.render()})
        add(label(String(format:"Balance %.2f · %@",record.magnitude,record.direction),size:16));add(label(String(format:"x %+.2f · y %+.2f",record.x,record.y),muted:true))
        add(label(День.порядок.map{String(format:"%@: %.1f",Copy.name($0),record.sums[$0] ?? 0)}.joined(separator:" · ")))
        rule();add(label("Change since previous observation",size:16))
        if let comparison=HistoryComparison.find(for:record,in:points) {
            let stamp=DateFormatter();stamp.locale=Locale(identifier:"en_US_POSIX");stamp.dateFormat="dd MMM yyyy HH:mm:ss Z"
            add(label(stamp.string(from:comparison.previous.collected)+" →\n"+stamp.string(from:record.collected),size:10,muted:true))
            add(label("Elapsed: \(comparison.intervalText) · selected minus previous",size:10,muted:true))
            if comparison.comparable {
                add(label(String(format:"Δ balance %+.2f · Δ x %+.2f · Δ y %+.2f",record.magnitude-comparison.previous.magnitude,record.x-comparison.previous.x,record.y-comparison.previous.y)))
                for arm in День.порядок {
                    let weight=comparison.sumDelta(arm).map{String(format:"%+.1f",$0)} ?? "unavailable"
                    let count=comparison.countDelta(arm).map{String(format:"%+d",$0)} ?? "unavailable"
                    add(label("\(Copy.name(arm)): Δ weight \(weight) · Δ blocks \(count)",size:11))
                }
            } else {
                add(label("Comparison unavailable: calculation rules changed.\n\(comparison.previous.rules) → \(record.rules)",size:11))
            }
            add(label("Endpoint changes only. Unobserved time is not reconstructed; missing days stay blank in the chart.",size:10,muted:true))
        } else {
            add(label("First available observation for this source and mode. No earlier snapshot to compare.",size:11,muted:true))
        }
        rule()
        add(label("Sources at capture · "+record.sources.keys.sorted().map{Copy.name($0)+": "+Copy.status(record.sources[$0]!)}.joined(separator:" · "),size:10,muted:true))
        add(label("Scale: \(record.rules) · \(Copy.name(record.mode))\nPoints are saved observations. Missing data and scale changes break the line. Weights reflect the rules used at capture time.",size:10,muted:true))
    }
    private func settings() {
        add(label("Your sources",size:18))
        add(label("Calendar works locally. A private board is optional; its address stays in this Mac's preferences.",muted:true))
        let address=NSTextField(string:boardAddress);address.font=UI.mono(11);address.placeholderString="https://your-private-board.example";address.translatesAutoresizingMaskIntoConstraints=false;address.widthAnchor.constraint(equalToConstant:Self.content-14).isActive=true;address.heightAnchor.constraint(equalToConstant:30).isActive=true;address.setAccessibilityLabel("Private board address");add(address)
        add(row([button("connect board",width:180,tip:"save a valid HTTP(S) board address and refresh"){[weak self] in guard let self else{return};self.feedback=self.saveBoard?(address.stringValue) == true ? "Board saved":"Enter a valid HTTP(S) address without a username or password";self.render()},button("use calendar only",width:180,tip:"remove the board setting; keep all local history"){[weak self] in guard let self else{return};_ = self.saveBoard?("");self.render()}]))
        if !feedback.isEmpty {add(label(feedback,size:10,muted:true))}
        let shared=UserDefaults.standard.bool(forKey:CalendarBoardBridge.enabledKey)
        add(button(shared ? "calendar sharing: on":"calendar sharing: off",width:280,tip:"send event titles and times to your configured private board; off by default"){[weak self] in UserDefaults.standard.set(!shared,forKey:CalendarBoardBridge.enabledKey);self?.обновить?();self?.render()})
        add(label("Optional sharing sends titles and times to your configured board every source check. No attendees, notes or meeting links are shared. "+bridgeStatus,size:10,muted:true))
        rule();add(label("Event check-ins",size:18))
        let available=CheckInConnection.root(boardAddress) != nil
        let sync=button(reviewSyncEnabled ? "ratings sync: on":"ratings sync: off",width:300,tip:"share ratings, event times and the optional sentence with your configured private board; on for an existing connection"){[weak self] in guard let self else{return};self.toggleReviewSync?(!self.reviewSyncEnabled)}
        sync.isEnabled=available;add(sync)
        add(label("Private board connection enables ratings sync by default. With no board, check-ins stay local. Public demonstration boards are excluded. "+reviewSyncStatus,size:10,muted:true))
        let reminders=UserDefaults.standard.bool(forKey:EventNotices.enabledKey)
        add(button(reminders ? "check-in reminders: on":"check-in reminders: off",width:300,tip:"one quiet notification after a freshly observed event ends; no backfill or event title"){[weak self] in self?.toggleReminders?(!reminders)})
        add(label(noticeStatus,size:10,muted:true));add(label("Feeling and energy are personal reports on a −2…+2 scale. They never mark a task complete or diagnose a state. Private optional notes are kept separately from aggregate history.",size:10,muted:true));rule()
        add(button("show my local records",width:260,tip:"open the local data folder; history, check-ins and install backups remain under your control"){
            NSWorkspace.shared.activateFileViewerSelecting([FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Krest")])
        })
        add(label("Menu bar",size:18));let modes=["mark","mark + value","value","hidden"]
        add(KrestPopUp(items:["Mark · default","Mark + direction & value","Direction & value","Hide…"],selected:modes.firstIndex(of:menuMode) ?? 0,width:300,tip:"how the menu bar item looks; hide asks first and names the way back"){[weak self] i in self?.setMenuMode?(modes[i]);self?.render()})
        let preview=NSImageView();preview.image=menuMode == "value" || menuMode == "hidden" ? nil:Знак.образ(x:day?.x ?? 0,y:day?.y ?? 0,тревога:(day?.перекос ?? 0)>=0.5)
        let caption=NSTextField(labelWithString:menuMode == "hidden" ? "Hidden" : ["value","mark + value"].contains(menuMode) ? String(format:"%.2f · %@",day?.перекос ?? 0,day?.куда ?? "unknown"):"Current balance mark");caption.font=UI.mono(11);add(row([preview,caption]))
        add(label("The mark shows balance direction. A filled centre dot means imbalance ≥ 0.50; ! marks an error or a snapshot older than one hour. Hover for the source receipt.",muted:true))
        add(label("Panel pin",size:18));add(label("The circle beside × is a pin control. Filled = keep this panel open when you click elsewhere; hollow = close on an outside click. It is separate from the balance dot.",muted:true))
        add(button(pin.pinned ? "unpin panel":"keep panel open",width:200,tip:"the same switch as the circle in the header; it survives a restart"){[weak self] in guard let self else{return};self.pin.setPinned(!self.pin.pinned);self.onPin?(self.pin.pinned);self.render()})
        add(label("Theme",size:18));add(label("White by default. Black turns the panel, its menus and its alerts dark; the menu bar mark follows macOS and the character keeps its white plate. The same switch sits in the footer.",muted:true))
        let mode=AIMThemePolicy.load()
        let settingTheme=AIMThemeButton(mode:mode)
        settingTheme.onChange={[weak self] next in self?.themeButton.setMode(next);self?.onTheme?(next)}
        let themeLabel=NSTextField(labelWithString:mode == .dark ? "black theme":"white theme");themeLabel.font=UI.mono(11);themeLabel.textColor=UI.gray600
        add(row([settingTheme,themeLabel]))
        add(label("Global key",size:18));add(label("One combination opens and closes this panel from any app. Press the field, then the keys: esc keeps the old one, delete clears it. A combination another AIM app or macOS holds is refused by name.",muted:true))
        if let store=hotkeyStore {
            let field=FamilyHotkeyField(store:store,width:160);keyField=field
            field.onLine={[weak self] line in self?.hotkeyLine=line}
            field.onChange={[weak self] combo in self?.onHotkey?(combo);self?.render()}
            var picks:[NSView]=[field]
            for pick in [FamilyHotkey(keyCode:7,modifiers:[.option,.command],character:"x"),FamilyHotkey(keyCode:7,modifiers:[.control,.option],character:"x"),FamilyHotkey(keyCode:7,modifiers:[.option,.shift],character:"x")] {
                picks.append(button(pick.display,width:72,tip:"quick pick: use \(pick.display) if nobody holds it"){[weak self] in
                    guard let self else{return}
                    if let refusal=pick.conflict(against:FamilyHotkeys.holders(excluding:FamilyHotkeys.krest)) {self.hotkeyLine="\(pick.display) refused: \(refusal)"}
                    else {store.store(pick);self.hotkeyLine="stored \(pick.display)";self.onHotkey?(pick)}
                    self.render()})
            }
            add(row(picks))
            add(label(hotkeyLine.isEmpty ? (hotkeyAvailable ? "default ⌥⌘X, the cross" : "the combination is held by another app") : hotkeyLine,size:10,muted:true))
            add(label("Family keys · "+FamilyHotkeys.printedRows.joined(separator:" · "),size:10,muted:true))
        }
        add(label("Calendar & observation",size:18));add(label("Day reads Calendar Control’s Google snapshot, or macOS Calendar when no snapshot exists. Source and capture time stay visible. A minute tick updates event phases and checks available sources; it does not fetch a new Google export. Open Calendar Control to refresh its connector.",muted:true))
        add(label("History stays on this Mac: capture time, balance, arm totals and source states. No event titles, messages or task text are written to the history file. Each board and calendar has a separate history.",muted:true))
        add(label("Finite refresh feedback and shared voxel gestures respect Reduce Motion.\n1 Balance · 2 Day · 3 History · 4 Settings\n⌘, settings · ⌘R refresh · ⌘K actions · Esc back / close · ⌘W close"+(hotkeyStore?.current.map{" · "+$0.display+" open and close"} ?? ""),muted:true))
    }
}
