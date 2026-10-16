// крест · строка меню
//
// Показывает перекос дня одним числом в строке меню и раскладку по четырём лучам
// в панели. Данные берёт у живого борта по адресу KREST_URL; когда борт недоступен,
// сохраняет последний снимок и показывает ошибку источника.
//
// Профиль N1: белая поверхность, IBM Plex Mono, красный дозой.

import AppKit
import EventKit
import Foundation
import CoreText

// MARK: - токены

enum UI {
    static func hex(_ s: String) -> NSColor {
        var v: UInt64 = 0
        Scanner(string: s.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
        return NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255,
                       green: CGFloat((v >> 8) & 0xff) / 255,
                       blue: CGFloat(v & 0xff) / 255, alpha: 1)
    }
    static let white = AIMAppShellStyle.canvas
    static let ink = AIMAppShellStyle.ink
    static let gray600 = AIMAppShellStyle.muted
    static let gray200 = AIMAppShellStyle.divider
    static let gray50 = AIMAppShellStyle.hover
    static let red = AIMAppShellStyle.signal

    static func registerFonts() {
        for weight in [400,500,600] {
            if let url=Bundle.main.url(forResource:"plex-mono-\(weight)",withExtension:"ttf") { CTFontManagerRegisterFontsForURL(url as CFURL,.process,nil) }
        }
        AIMAppShellStyle.font = { size,weight in
            let suffix=weight >= .semibold ? "-SmBld" : weight >= .medium ? "-Medm" : ""
            return NSFont(name:"IBMPlexMono"+suffix,size:size) ?? NSFont.monospacedSystemFont(ofSize:size,weight:weight)
        }
    }
    static func mono(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
        return AIMAppShellStyle.font(size, weight)
    }
}

// MARK: - день

/// Срез дня. Поля повторяют контекст.json, лишнего не читаем.
struct День {
    struct Луч { let имя: String; let сумма: Double; let штук: Int; let верх: [Блок] }
    struct Блок { let т: String; let вес: Double; let природа: String }
    struct Источник { let имя: String; let статус: String; var note: String = "" }
    struct Fact { let title: String; let time: String; let detail: String }

    let дата: String
    let собрано: String
    let лучи: [Луч]
    let x: Double
    let y: Double
    let источники: [Источник]
    var rulesVersion: String = "unknown"
    var facts: [Fact] = []
    var calendarBlockCount: Int = 0
    var promiseBlockCount: Int = 0
    let живой: Bool          // с борта, а не из встроенного образца
    var режим: Режим = .образец
    var calendarItems: [[String: String]] = []
    var focusNotice: String? = nil

    enum Режим: String {
        case борт = "борт"          // девять источников с живого борта
        case календарь = "календарь" // календарь этого мака, без сети
        case образец = "выдуманный день"
        var title:String {self == .борт ? "Board snapshot" : self == .календарь ? "Calendar estimate":"Fictional example"}
    }

    static let порядок = ["обязательства", "ресурсы", "будущее", "прошлое"]

    static func разобрать(_ data: Data, живой: Bool) -> День? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let лучиRaw = o["лучи"] as? [String: Any],
              let date = o["дата"] as? String, !date.isEmpty,
              let balance = o["баланс"] as? [String: Any],
              let x = balance["x"] as? Double, let y = balance["y"] as? Double,
              x.isFinite, y.isFinite, abs(x) <= 1, abs(y) <= 1 else { return nil }

        var лучи: [Луч] = []
        for имя in порядок {
            guard let l = лучиRaw[имя] as? [String: Any],
                  let sum = l["сумма"] as? Double, sum.isFinite,
                  l["элементы"] is [[String: Any]] else { return nil }
            let элементы = (l["элементы"] as? [[String: Any]]) ?? []
            let верх = элементы
                .compactMap { e -> Блок? in
                    guard let т = e["т"] as? String else { return nil }
                    let вес = (e["вес"] as? Double) ?? 0
                    return Блок(т: т, вес: вес, природа: (e["природа"] as? String) ?? "тянет")
                }
                .sorted { abs($0.вес) > abs($1.вес) }
                .prefix(3)
            лучи.append(Луч(имя: имя,
                            сумма: (l["сумма"] as? Double) ?? 0,
                            штук: (l["штук"] as? Int) ?? элементы.count,
                            верх: Array(верх)))
        }

        let баланс = (o["баланс"] as? [String: Any]) ?? [:]
        let ист = (o["источники"] as? [String: Any]) ?? [:]
        let источники = ист.keys.sorted().map {
            Источник(имя: $0, статус: ((ист[$0] as? [String: Any])?["статус"] as? String) ?? "?", note:((ист[$0] as? [String:Any])?["заметка"] as? String) ?? "")
        }

        return День(дата: (o["дата"] as? String) ?? "",
                    собрано: (o["собрано"] as? String) ?? "",
                    лучи: лучи,
                    x: (баланс["x"] as? Double) ?? 0,
                    y: (баланс["y"] as? Double) ?? 0,
                    источники: источники,
                    rulesVersion: (o["правила_версия"] as? String) ?? "unknown",
                    facts: (o["факты"] as? [[String:Any]] ?? []).compactMap { f in guard let title=f["что"] as? String else{return nil};return Fact(title:title,time:f["t"] as? String ?? "",detail:f["дало"] as? String ?? "") },
                    calendarBlockCount: лучиRaw.values.compactMap{$0 as? [String:Any]}.flatMap{$0["элементы"] as? [[String:Any]] ?? []}.filter{$0["источник"] as? String == "календарь"}.count,
                    promiseBlockCount: лучиRaw.values.compactMap{$0 as? [String:Any]}.flatMap{$0["элементы"] as? [[String:Any]] ?? []}.filter{$0["источник"] as? String == "обещания"}.count,
                    живой: живой && o["fictional"] as? Bool != true,
                    режим: живой && o["fictional"] as? Bool != true ? .борт : .образец,
                    calendarItems: ((o["день"] as? [[String: Any]]) ?? []).compactMap { item in
                        guard let time = item["t"] as? String, let title = item["что"] as? String,
                              let ids = item["элементы"] as? [String], ids.contains(where: { $0.hasPrefix("cal-") }) else { return nil }
                        return ["time": time, "title": title, "end": item["конец"] as? String ?? time]
                    },
                    focusNotice: (o["фокус"] as? [String: Any])?["заметка"] as? String)
    }

    /// Куда тянет: словами, по тому же знаку, что рисует поле.
    var куда: String {
        if перекос < 0.01 { return "balanced" }
        let вертикаль = abs(y) >= abs(x)
        if вертикаль { return y < 0 ? "toward obligations" : "toward resources" }
        return x < 0 ? "toward the past" : "toward the future"
    }
    var перекос: Double { max(abs(x), abs(y)) }
}

// Состояние соединения отдельно от времени сборки: одинаковый баланс не означает зависание.
enum Свежесть {
    static func дата(_ value: String) -> Date? {
        let f = ISO8601DateFormatter()
        for options: ISO8601DateFormatter.Options in [.withInternetDateTime, [.withInternetDateTime, .withFractionalSeconds]] {
            f.formatOptions = options
            if let d = f.date(from: value) { return d }
        }
        let short = DateFormatter(); short.locale = Locale(identifier: "en_US_POSIX")
        short.dateFormat = "yyyy-MM-dd'T'HH:mmXXX"
        return short.date(from: value)
    }
    static func описание(_ value: String, now: Date = Date()) -> String {
        guard let d = дата(value) else { return value.isEmpty ? "Snapshot time unknown" : value }
        let f = DateFormatter(); f.dateFormat = "dd.MM HH:mm"
        let age = max(0, Int(now.timeIntervalSince(d) / 60))
        return "Snapshot " + f.string(from: d) + (age >= 60 ? " · stale (\(age / 60) h)" : " · \(age) min ago")
    }
    static func endpoint(_ address: String) -> URL? {
        guard var c = URLComponents(string: address), ["https", "http"].contains(c.scheme ?? ""),
              c.host != nil, c.user == nil, c.password == nil else { return nil }
        var path = c.path
        if path.hasSuffix("/index.html") { path = String(path.dropLast(11)) }
        if path.hasSuffix("/контекст.json") { path = String(path.dropLast(14)) }
        while path.hasSuffix("/") { path.removeLast() }
        c.path = path + "/контекст.json"; c.query = nil; c.fragment = nil
        return c.url
    }
}

// MARK: - день из календаря этого мака

/// Публичная сборка: крест только по календарю, без сети и без сервера.
/// Веса взяты из правил открытой версии: база 1, плюс 0.5 за участника сверх меня,
/// потолок 3; встреча длиннее 90 минут тяжелее в полтора раза; свободные часы
/// рабочего дня уходят опорой на нижний луч, ноль часов даёт дефицит.
enum Календарь {
    static let хранилище = EKEventStore()

    static func доступ(_ готово: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            хранилище.requestFullAccessToEvents { ok, _ in DispatchQueue.main.async { готово(ok) } }
        } else {
            хранилище.requestAccess(to: .event) { ok, _ in DispatchQueue.main.async { готово(ok) } }
        }
    }

    static func день() -> День? { CalendarBridge.day(CalendarBridge.load()) }

}

// MARK: - знак в строке меню

/// Крест из четырёх лучей и точка баланса, нарисованный в образ.
/// Подвид на кнопке статус-элемента AppKit не рисует, поэтому только NSImage.
/// Образ шаблонный: строка меню сама красит его под свою тему.
enum Знак {
    /// Образ строится через lockFocus, а не через NSImage(size:flipped:drawingHandler:).
    /// Ленивый обработчик строка меню не вызывает, и элемент занимает место, ничего не рисуя:
    /// Checked сравнением снимков строки меню до и после.
    static func образ(x: Double, y: Double, тревога: Bool) -> NSImage {
        let сторона: CGFloat = 18
        let img = NSImage(size: NSSize(width: сторона, height: сторона))
        img.lockFocus()
        // Rasterize the canonical shared mark; add only the observed balance dot.
        let transform = NSAffineTransform(); transform.translateX(by: 0, yBy: сторона); transform.scaleX(by: 1, yBy: -1); transform.concat()
        AIMAppMarkView.draw(.krest, in: NSRect(x:0,y:0,width:сторона,height:сторона), mono:true)
        let bx = сторона / 2 + CGFloat(x) * 4.1, by = сторона / 2 + CGFloat(y) * 4.1
        let dot = NSBezierPath(ovalIn: NSRect(x:bx-1.65,y:by-1.65,width:3.3,height:3.3))
        NSGraphicsContext.current?.cgContext.setBlendMode(.clear); dot.fill()
        NSGraphicsContext.current?.cgContext.setBlendMode(.normal)
        NSColor.black.setFill(); NSColor.black.setStroke();dot.lineWidth=1
        if тревога { dot.fill() } else { dot.stroke() }
        img.unlockFocus()
        img.isTemplate = true
        return img
    }
}

// MARK: - приложение

final class Delegate: NSObject, NSApplicationDelegate {
    private var статус: NSStatusItem!
    private let панель = NSPopover()
    private lazy var вид = AIMThemePolicy.withAppearance(AIMThemePolicy.load()) { ПанельView(frame: NSRect(x: 0, y: 0, width: ПанельView.width, height: ПанельView.height)) }
    private var таймер: Timer?
    private var день: День?
    private var loading = false
    private var состояние = "Connecting…"
    private var lastData: Data?
    private var ответ = ""
    private var pulse: Timer?
    private let historyStore = BalanceHistory()
    private let historySync = HistorySync()
    private let reviewStore = EventReviewStore()
    private let eventNotices = EventNotices()
    private var lastBridgeCapture:Date?
    private var historyStatus = "Local history"
    private lazy var surface = AIMSurface(host:.popover(панель))
    private var keyMonitor: Any?
    private var menuTracking=false
    private var failed = false
    private var calendarFrame: CalendarFrame?
    private var calendarLoading=false
    private var calendarObserver: NSObjectProtocol?
    private var menuMode: String { UserDefaults.standard.string(forKey:"KrestMenuMode") ?? "mark" }
    /// Rule 31: the pin survives a restart under one key; a value from a build before the shared contract
    /// migrates to off once under `AIMPinPolicy.migrationKey`, the same key MEM PRISM uses.
    static let pinKey = "org.aimindset.krest.bar.pinned"
    /// Rule 49: ⌥⌘X, the cross. Stored as `org.aimindset.krest.bar.hotkey`, recorded in settings (rule 50).
    static let hotkeyStore = FamilyHotkeyStore(owner: FamilyHotkeys.krest,
                                               fallback: FamilyHotkey(keyCode: 7, modifiers: [.option, .command], character: "x"))
    private lazy var hotkey = FamilyHotkeyRegistrar(signature: 0x4B727374) { [weak self] in self?.toggleFromHotkey() }
    private(set) var hotkeyAvailable = true

    static func loadPin(_ d: UserDefaults = .standard) -> Bool {
        let resolution = AIMPinPolicy.resolve(stored: d.object(forKey: pinKey) == nil ? nil : d.bool(forKey: pinKey),
                                              migrated: d.bool(forKey: AIMPinPolicy.migrationKey))
        if resolution.writePinned { d.set(resolution.pinned, forKey: pinKey) }
        if resolution.markMigrated { d.set(true, forKey: AIMPinPolicy.migrationKey) }
        return resolution.pinned
    }

    private func refreshHistory(force: Bool = false) {
        updateHistoryView()
        guard let address = адрес else { return }
        historySync.load(address:address,store:historyStore,force:force) { [weak self] status in
            self?.historyStatus=status;self?.updateHistoryView()
        }
    }
    private func updateHistoryView() {
        let mode = адрес == nil ? "календарь" : "борт"
        вид.history(historyStore.points(sourceID:BalanceRecord.source(адрес),mode:mode),status:historyStore.issue ?? historyStatus)
    }
    private func paintStatus() {
        статус.isVisible = menuMode != "hidden"
        статус.button?.image = menuMode == "value" ? nil : Знак.образ(x:день?.x ?? 0,y:день?.y ?? 0,тревога:(день?.перекос ?? 0)>=0.5)
        let stale = день.flatMap { Свежесть.дата($0.собрано) }.map { Date().timeIntervalSince($0)>3600 } ?? false
        let value = день.map { " "+(abs($0.y)>=abs($0.x) ? ($0.y<0 ? "↑":"↓") : ($0.x<0 ? "←":"→"))+String(format:" %.2f",$0.перекос) } ?? " –"
        статус.button?.title = (["mark + value","value"].contains(menuMode) ? value : "") + (failed || stale ? " !" : "")
        вид.menuMode=menuMode
        let key = Self.hotkeyStore.current.map { " · \($0.display) opens and closes" } ?? ""
        статус.button?.toolTip = "Krest · " + (день.map { String(format:"balance %.2f toward %@", $0.перекос, $0.куда) } ?? "waiting for data")
            + (failed ? " · source error" : stale ? " · snapshot older than an hour" : "") + key + "\nclick: panel · right-click: actions"
    }
    private func chooseMenuMode(_ mode:String) {
        if mode == "hidden" {
            let alert=NSAlert();alert.messageText="Hide Krest from the menu bar?"
            alert.informativeText="Open Krest again from Applications or Spotlight to restore the menu mark and panel."
            alert.addButton(withTitle:"Hide");alert.addButton(withTitle:"Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        UserDefaults.standard.set(mode,forKey:"KrestMenuMode");paintStatus()
    }

    /// Адрес борта. Своего адреса у приложения нет: без настройки оно живёт на
    /// встроенном выдуманном дне. Задаётся один раз:
    ///   defaults write org.aimindset.krest.bar KrestURL "https://твой-борт:8460"
    private var адрес: String? {
        if let e = ProcessInfo.processInfo.environment["KREST_URL"], !e.isEmpty { return e }
        if let d = UserDefaults.standard.string(forKey: "KrestURL"), !d.isEmpty { return d }
        return nil
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UI.registerFonts()
        // Rule 53: the theme is applied before the first view is built, so the panel never opens in the other colour.
        AIMThemePolicy.apply(AIMThemePolicy.load())

        статус = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        статус.autosaveName = "KrestStatus"
        if let b = статус.button {
            b.image = Знак.образ(x: 0, y: 0, тревога: false)
            b.title = " ·"
            b.setAccessibilityLabel("Krest – open balance panel")
            b.imagePosition = .imageLeading
            b.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            b.target = self
            b.action = #selector(клик)
            b.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        панель.contentViewController = NSViewController()
        панель.contentViewController?.view = вид
        панель.contentSize = NSSize(width: ПанельView.width, height: ПанельView.height)
        панель.behavior = .applicationDefined
        вид.открытьБорт = { [weak self] in self?.открытьБорт() }
        вид.обновить = { [weak self] in self?.забрать() }
        вид.syncHistory = { [weak self] in self?.refreshHistory(force:true) }
        вид.close = { [weak self] in self?.surface.close(reason:.closeButton) }
        let pinned = Self.loadPin()
        вид.pin.setPinned(pinned); surface.pinned = pinned
        вид.onPin = { [weak self] pinned in UserDefaults.standard.set(pinned, forKey: Self.pinKey); self?.surface.pinned = pinned }
        вид.onTheme = { [weak self] mode in AIMThemePolicy.store(mode); AIMThemePolicy.apply(mode); AIMThemePolicy.withAppearance(mode) { self?.вид.themeChanged(mode) } }
        вид.hotkeyStore = Self.hotkeyStore
        вид.onHotkey = { [weak self] combo in self?.registerHotkey(combo) }
        вид.openCalendar = {
            let own=URL(fileURLWithPath:NSHomeDirectory()+"/Applications/Calendar Control.app")
            if FileManager.default.fileExists(atPath:own.path) {NSWorkspace.shared.open(own)}
            else if let calendar=NSWorkspace.shared.urlForApplication(withBundleIdentifier:"com.apple.iCal") {NSWorkspace.shared.open(calendar)}
        }
        вид.reviews=reviewStore
        вид.saveReview = { [weak self] event,feeling,energy,text in self?.reviewStore.save(event,feeling:feeling,energy:energy,reframe:text) ?? false }
        вид.boardAddress=адрес ?? ""
        вид.saveBoard = { [weak self] address in
            let trimmed=address.trimmingCharacters(in:.whitespacesAndNewlines)
            guard trimmed.isEmpty || Свежесть.endpoint(trimmed) != nil else{return false}
            UserDefaults.standard.set(trimmed,forKey:"KrestURL");self?.вид.boardAddress=trimmed
            self?.lastBridgeCapture=nil;self?.забрать();return true
        }
        вид.toggleReminders = { [weak self] enabled in
            self?.eventNotices.setEnabled(enabled) { [weak self] in
                guard let self else{return};self.вид.noticeStatus=self.eventNotices.status;self.вид.refreshPreferences()
            }
        }
        eventNotices.openDay = { [weak self] in self?.showDay() }
        вид.reflect = { [weak self] title,date in
            guard let address=self?.адрес,let endpoint=Свежесть.endpoint(address),var c=URLComponents(url:endpoint.deletingLastPathComponent().appendingPathComponent("отклик"),resolvingAgainstBaseURL:false) else{return}
            c.queryItems=[URLQueryItem(name:"событие",value:title),URLQueryItem(name:"дата",value:date),URLQueryItem(name:"луч",value:"ресурсы")]
            if let url=c.url {NSWorkspace.shared.open(url)}
        }
        вид.setMenuMode = { [weak self] mode in self?.chooseMenuMode(mode) }
        keyMonitor=NSEvent.addLocalMonitorForEvents(matching:.keyDown) { [weak self] event in
            // The local monitor belongs to this process; popover key events may have no window.
            guard let self,self.surface.isShown else{return event}
            guard KrestKeyScope.accepts(shown:self.surface.isShown,modal:NSApp.modalWindow != nil,
                sheet:self.вид.window?.attachedSheet != nil,menu:self.menuTracking,
                eventWindow:event.window?.windowNumber,panelWindow:self.вид.window?.windowNumber) else{return event}
            if self.вид.handlePanelKey(event) {return nil}
            if let reason=self.surface.closeReason(for:event) { self.surface.close(reason:reason);return nil }
            if event.modifierFlags.contains(.command),(event.keyCode == 40 || event.charactersIgnoringModifiers?.lowercased()=="k") {self.меню();return nil}
            if event.modifierFlags.contains(.command),(event.keyCode == 15 || event.charactersIgnoringModifiers?.lowercased()=="r") { self.забрать();return nil }
            if !event.modifierFlags.intersection([.command,.control,.option]).isEmpty { return event }
            if event.window?.firstResponder is NSTextView {return event}
            if let key=event.charactersIgnoringModifiers,let index=Int(key),(1...4).contains(index) { self.вид.select(["now","day","history","settings"][index-1]);return nil }
            return event
        }
        registerHotkey(Self.hotkeyStore.current)
        paintStatus()
        refreshHistory()
        calendarObserver=NotificationCenter.default.addObserver(forName:.EKEventStoreChanged,object:nil,queue:.main) { [weak self] _ in self?.refreshCalendar() }

        // Первый сбор откладывается: синхронный EventKit на главном потоке при запуске
        // не даёт строке меню нарисовать элемент, он занимает место и остаётся пустым.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.забрать() }
        таймер = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.забрать() }
        RunLoop.main.add(таймер!, forMode: .common)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(забрать), name: NSWorkspace.didWakeNotification, object: nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !surface.isShown {
            if menuMode == "hidden" { UserDefaults.standard.set("mark",forKey:"KrestMenuMode");paintStatus() }
            showPanel()
        }
        return true
    }

    private func registerHotkey(_ combo: FamilyHotkey?) {
        hotkeyAvailable = hotkey.register(combo)
        вид.hotkeyState(combo: combo, available: hotkeyAvailable)
        paintStatus()
    }
    /// Rule 49: one key opens and closes; it reaches the same close as Escape and the bar item.
    private func toggleFromHotkey() {
        if surface.isShown { surface.close(reason:.hotkey); return }
        if menuMode == "hidden" { UserDefaults.standard.set("mark",forKey:"KrestMenuMode");paintStatus() }
        showPanel()
    }

    @objc private func клик() {
        if let e = NSApp.currentEvent, e.type == .rightMouseUp { меню(); return }
        if surface.isShown { surface.close(reason:.menuBarItem);return }
        showPanel()
    }
    private func showPanel() {
        вид.показать(день)
        вид.соединение(состояние, loading: loading)
        if let b = статус.button {
            surface.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
            забрать();refreshHistory()
        }
    }

    private func меню() {
        menuTracking=true;defer{menuTracking=false}
        let m = NSMenu()
        let title=m.addItem(withTitle:"Krest · "+(день?.куда ?? "waiting for data"),action:nil,keyEquivalent:"");title.isEnabled=false
        m.addItem(withTitle:"Today & calendar…",action:#selector(showDay),keyEquivalent:"2").target=self
        m.addItem(.separator())
        m.addItem(withTitle: "Refresh sources", action: #selector(забрать), keyEquivalent: "r").target = self
        m.addItem(withTitle: "Open private board…", action: #selector(открытьБорт), keyEquivalent: "o").target = self
        m.addItem(withTitle:"Balance history…",action:#selector(showHistory),keyEquivalent:"3").target=self
        m.addItem(withTitle:"Settings…",action:#selector(showSettings),keyEquivalent:",").target=self
        m.addItem(.separator())
        m.addItem(withTitle: "Quit Krest", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let tips=["Today & calendar…":"open the panel on today's calls and calendar load","Refresh sources":"read the board or the calendar again now",
                  "Open private board…":"open the private board in the browser","Balance history…":"open the panel on saved observations",
                  "Settings…":"menu bar mode, pin, theme and the global key","Quit Krest":"stop krest; the history file stays on this Mac"]
        for item in m.items { if let tip=tips[item.title] { item.toolTip=tip } }
        if surface.isShown {
            m.popUp(positioning:nil,at:NSPoint(x:20,y:72),in:вид)
        } else if let button=статус.button {
            m.popUp(positioning:nil,at:NSPoint(x:0,y:button.bounds.minY),in:button)
        }
    }

    @objc private func showDay(){showPanel();вид.select("day")}
    @objc private func showHistory(){showPanel();вид.select("history")}
    @objc private func showSettings(){showPanel();вид.select("settings")}
    @objc private func открытьБорт() {
        guard let а = адрес, let u = URL(string: а) else { return }
        NSWorkspace.shared.open(u)
    }

    /// Борт, если задан адрес. Иначе календарь этого мака. Иначе встроенный образец.
    /// Панель всегда что-то показывает, пустого экрана не бывает.
    @objc private func забрать() {
        guard !loading else { return }
        refreshCalendar()
        loading = true
        состояние = "Checking source…"
        вид.соединение(состояние, loading: true)
        guard let а = адрес else { ответ = ""; изКалендаря(); return }
        guard let u = Свежесть.endpoint(а) else { ошибка("Invalid board address"); return }
        var req = URLRequest(url: u)
        req.timeoutInterval = 8
        req.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                guard error == nil else { self.ошибка("Board unavailable (network)"); return }
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    self.ошибка("HTTP error \((response as? HTTPURLResponse)?.statusCode ?? 0)"); return
                }
                guard let data, let д = День.разобрать(data, живой: true) else {
                    self.ошибка("Invalid board snapshot"); return
                }
                self.ответ = self.lastData == data ? "Snapshot unchanged" : "New snapshot received"
                self.lastData = data
                self.принять(д)
            }
        }.resume()
    }

    private func ошибка(_ message: String) {
        loading = false
        failed = true
        состояние = message + (день == nil ? " · try Refresh" : " · last snapshot retained")
        вид.показать(день)
        вид.соединение(состояние, loading: false)
        paintStatus()
        статус.button?.toolTip = "Krest · " + состояние
    }

    /// Конечный отклик на проверку. Координаты баланса при этом остаются настоящими.
    private func отклик() {
        pulse?.invalidate()
        статус.button?.alphaValue=1
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let start = Date()
        pulse = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            let p = min(1, Date().timeIntervalSince(start) / 0.65)
            self.статус.button?.alphaValue = 1 - 0.4 * sin(p * .pi)
            if p >= 1 { self.статус.button?.alphaValue = 1; t.invalidate() }
        }
        RunLoop.main.add(pulse!, forMode: .common)
    }

    private func refreshCalendar() {
        guard !calendarLoading else{return};calendarLoading=true
        DispatchQueue.global(qos:.utility).async { [weak self] in
            let frame=CalendarBridge.load()
            DispatchQueue.main.async {
                guard let self else{return};self.calendarLoading=false;self.calendarFrame=frame
                self.вид.calendar(frame)
                self.eventNotices.update(frame,reviews:self.reviewStore)
                self.вид.noticeStatus=self.eventNotices.status
                if UserDefaults.standard.bool(forKey:CalendarBoardBridge.enabledKey),let address=self.адрес,
                   frame.fresh(at:Date()),frame.fetched != self.lastBridgeCapture {
                    CalendarBoardBridge.send(frame,address:address) { [weak self] status in
                        guard let self else{return};self.вид.bridgeStatus=status
                        if status.contains("received") {self.lastBridgeCapture=frame.fetched}
                        self.вид.refreshPreferences()
                    }
                }
            }
        }
    }

    /// Публичный путь: крест по календарю этого мака, без сети.
    private func изКалендаря() {
        if FileManager.default.fileExists(atPath:CalendarBridge.snapshotURL.path) {
            DispatchQueue.global(qos:.utility).async { [weak self] in
                let d=CalendarBridge.day(CalendarBridge.load());DispatchQueue.main.async { if let d {self?.принять(d)}else{self?.ошибка("Calendar snapshot is stale or incomplete; open Calendar Control to refresh")} }
            };return
        }
        let статусДоступа = EKEventStore.authorizationStatus(for: .event)
        let разрешено: Bool
        if #available(macOS 14.0, *) { разрешено = статусДоступа == .fullAccess }
        else { разрешено = статусДоступа == .authorized }

        if разрешено {
            // Чтение календаря уходит с главного потока: оно может занять секунды.
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let д = Календарь.день()
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let д { self.принять(д) } else { self.образец() }
                }
            }
            return
        }
        if статусДоступа == .notDetermined {
            Календарь.доступ { [weak self] ok in
                guard let self else { return }
                if ok { self.изКалендаря() } else { self.образец() }
            }
            return
        }
        образец()
    }

    private func образец() {
        guard let p = Bundle.main.url(forResource: "демо", withExtension: "json"),
              let d = try? Data(contentsOf: p),
              let д = День.разобрать(d, живой: false) else { принять(nil); return }
        принять(д)
    }

    private func принять(_ д: День?) {
        if let d=д,let prev=historyStore.points(sourceID:BalanceRecord.source(адрес),mode:d.режим.rawValue).last {
            if Свежесть.дата(d.собрано) != prev.collected {
                вид.change = String(format:"Since previous snapshot · x %+.2f · y %+.2f",d.x-prev.x,d.y-prev.y)+"\n"+d.лучи.map { String(format:"%@ %+.1f",Copy.name($0.имя),$0.сумма-(prev.sums[$0.имя] ?? 0)) }.joined(separator:" · ")
            }
        }
        день = д
        failed = false
        loading = false
        if let d=д,let record=BalanceRecord.make(d,sourceID:BalanceRecord.source(адрес),origin:"наблюдение Mac") {
            historyStore.append(record);updateHistoryView()
        }
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        состояние = "Checked " + f.string(from: Date()) + " · " + ответ + "\nSource check every minute, on open and wake"
        вид.соединение(состояние, loading: false)
        отклик()
        paintStatus()
        статус.button?.toolTip = д.map {
            "Krest · \($0.дата) · balance \(String(format: "%.2f", $0.перекос)) \($0.куда)"
                + ($0.живой ? "" : " · fictional example") + " · " + состояние
        } ?? "Krest · no data"
        вид.показать(д)
    }
}
