import SwiftUI
import AppKit
import ServiceManagement

@MainActor final class Model: ObservableObject {
    let store = UserDefaults(suiteName:"local.PayDanceMac.Clock.preferences")!
    @Published var config: Config {
        didSet {
            if snapshot(.now).status != .invalidConfig, let data = try? JSONEncoder().encode(config) {
                store.set(data, forKey: "salary")
            }
        }
    }
    var applyTop: (() -> Void)?
    var applyLanguage: (() -> Void)?
    @Published var miniIsOnTop = true {
        didSet {
            store.set(miniIsOnTop, forKey: "top")
            applyTop?()
        }
    }
    @Published var step = 0
    @Published var sheet = ""
    @Published var login = SMAppService.mainApp.status == .enabled
    @Published var error = ""
    @Published var language: String {
        didSet {
            store.set(language, forKey: "language")
            applyLanguage?()
        }
    }
    func label(_ key:String)->String { language == "en" ? Self.translations[key] ?? key : key }
    static let translations = ["设置":"Settings",
"薪资详情":"Salary details",
"正在夜班":"Working night shift",
"夜班已完成":"Night shift complete",
"首次设置":"Welcome",
"完成":"Done",
"薪资模式":"Pay basis",
"月薪":"Monthly",
"日薪":"Daily",
"时薪":"Hourly",
"每月工作天数":"Workdays per month",
"货币符号":"Currency symbol",
"上班时间":"Shift start",
"下班时间":"Shift end",
"午休":"Lunch break",
"午休开始":"Break start",
"午休结束":"Break end",
"金额滚动动画":"Animate earnings",
"外观":"Appearance",
"系统":"System",
"浅色":"Light",
"深色":"Dark",
"迷你窗置顶":"Keep mini window on top",
"迷你窗透明度":"Mini window opacity",
"登录时启动":"Launch at login",
"今日收入":"Today's earnings",
"已工作":"Time worked",
"预计收入":"Estimated earnings",
"工作中":"Working",
"休息日":"Day off",
"已下班":"Shift complete",
"上班前":"Before work",
"午休中":"On break",
"请检查设置":"Check settings",
"距离上班":"Until shift starts",
"距离下班":"Until shift ends",
"今日完成":"Completed today",
"距离复工":"Until work resumes",
"配置异常":"Invalid configuration",
"打开主界面":"Open main window",
"迷你模式":"Mini mode",
"退出":"Quit",
"编辑":"Edit",
"剪切":"Cut",
"复制":"Copy",
"粘贴":"Paste",
"全选":"Select All",
"置顶":"Always on top",
"透明度":"Opacity",
"每日":"Per day",
"每小时":"Per hour",
"每分钟":"Per minute",
"每秒":"Per second",
"语言":"Language",
"重新配置":"Run setup again"]
    init() {
        if store.data(forKey:"salary") == nil,
           let dir = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask).first,
           let data = try? Data(contentsOf:dir.appendingPathComponent("com.hmilyhyun.salaryclock/salary-settings.json")),
           let old = try? JSONSerialization.jsonObject(with:data) as? [String:Any],
           let salary = old["config"], let raw = try? JSONSerialization.data(withJSONObject:salary),
           (try? JSONDecoder().decode(Config.self,from:raw)) != nil {
            store.set(raw,forKey:"salary")
            for (from,to) in [("currencySymbol","symbol"),("miniAlwaysOnTop","top"),("hasCompletedOnboarding","ready"),("isMiniMode","mini"),("locale","language")] { store.set(old[from],forKey:to) }
            if let percent = old["miniOpacityPercent"] as? Double { store.set(percent/100,forKey:"opacity") }
            store.set(old["amountMode"] as? String != "plain",forKey:"rolling")
            if old["followsSystemTheme"] as? Bool == false { store.set(old["themeMode"] as? String == "dark" ? "深色" : "浅色",forKey:"theme") }
        }
        miniIsOnTop = store.object(forKey:"top") as? Bool ?? true
        language = store.string(forKey: "language") ?? (Locale.preferredLanguages.first?.hasPrefix("zh") == true ? "zh-CN" : "en")
        config = (try? JSONDecoder().decode(Config.self, from: store.data(forKey:"salary") ?? Data())) ?? Config()
    }
    func snapshot(_ date: Date) -> SalarySnapshot {
        SalaryCalculator().snapshot(at: date, config: config)
    }
}
@main enum ClockApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let controller = Controller()
        app.delegate = controller
        let menu = NSMenu()
        let item = NSMenuItem()
        menu.addItem(item)
        let commands = NSMenu()
        let settings = commands.addItem(withTitle:"",action:#selector(Controller.showSettings),keyEquivalent:",")
        settings.target = controller
        let quit = commands.addItem(withTitle:"",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
        item.submenu = commands
        let edit = NSMenuItem()
        menu.addItem(edit)
        let editing = NSMenu()
        let editCommands = [
            ("剪切", "cut:", "x"),
            ("复制", "copy:", "c"),
            ("粘贴", "paste:", "v"),
            ("全选", "selectAll:", "a")
        ].map { title, action, shortcut in
            (title, editing.addItem(withTitle: "", action: NSSelectorFromString(action), keyEquivalent: shortcut))
        }
        edit.submenu = editing
        let model = controller.model
        model.applyLanguage = { [weak model] in
            guard let model else { return }
            settings.title = model.label("设置")
            quit.title = model.label("退出")
            editing.title = model.label("编辑")
            edit.title = editing.title
            for (title, command) in editCommands {
                command.title = model.label(title)
            }
        }
        model.applyLanguage?()
        app.mainMenu = menu
        withExtendedLifetime(controller) { app.run() }
    }
}

@MainActor final class MiniPanel: NSPanel {
    var restoreMainWindow: (() -> Void)?

    private var dragStart: (mouse: NSPoint, origin: NSPoint)?

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown where !event.modifierFlags.contains(.control):
            if event.clickCount == 2 {
                dragStart = nil
                restoreMainWindow?()
            } else {
                dragStart = (convertPoint(toScreen: event.locationInWindow), frame.origin)
            }
        case .leftMouseDragged where dragStart != nil:
            guard let start = dragStart else { return }
            let mouse = convertPoint(toScreen: event.locationInWindow)
            setFrameOrigin(NSPoint(x: start.origin.x + mouse.x - start.mouse.x,
                                   y: start.origin.y + mouse.y - start.mouse.y))
        case .leftMouseUp where dragStart != nil:
            dragStart = nil
        default:
            super.sendEvent(event)
        }
    }
}

@MainActor enum LegacyWindowLayout {
    static func restore(_ window: NSWindow, name: String, position: String, size: String) {
        if !window.setFrameUsingName(name),
           let dir = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask).first,
           let data = try? Data(contentsOf:dir.appendingPathComponent("com.hmilyhyun.salaryclock/salary-settings.json")),
           let legacy = try? JSONSerialization.jsonObject(with:data) as? [String:Any] {
            let dimensions = legacy[size] as? [String:Double]
            let point = legacy[position] as? [String:Double]
            let screens = NSScreen.screens
            if let primary = screens.first {
                let candidates = screens.compactMap { screen -> (NSScreen,NSPoint)? in
                    guard let x = point?["x"], let y = point?["y"] else { return nil }
                    let origin = NSPoint(x:x/screen.backingScaleFactor,y:primary.frame.maxY-y/screen.backingScaleFactor)
                    return screen.frame.insetBy(dx:-1,dy:-1).contains(origin) ? (screen,origin) : nil
                }
                let screen = candidates.first?.0 ?? primary
                let area = screen.visibleFrame
                let minSize = size == "miniSize" ? NSSize(width:148,height:44) : NSSize(width:430,height:410)
                let content = NSSize(width:min(area.width,max(minSize.width,dimensions?["width"] ?? window.contentRect(forFrameRect:window.frame).width)),height:min(area.height,max(minSize.height,dimensions?["height"] ?? window.contentRect(forFrameRect:window.frame).height)))
                window.setContentSize(content)
                if let top = candidates.first?.1 { window.setFrameTopLeftPoint(top) }
                var frame = window.frame
                frame.origin.x = max(area.minX,min(frame.minX,area.maxX-frame.width))
                frame.origin.y = max(area.minY,min(frame.minY,area.maxY-frame.height))
                window.setFrame(frame,display:false)
            }
        }
        window.setFrameAutosaveName(name)
        window.saveFrame(usingName:name)
    }
}

@MainActor final class Controller: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    let model = Model()
    var main: NSWindow!, panel: NSPanel!, status: NSStatusItem!
    func applicationDidFinishLaunching(_ note: Notification) {
        main = NSWindow(contentRect:NSRect(x:0,y:0,width:480,height:460),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        main.title = "Salary Clock"
        main.isReleasedWhenClosed = false
        main.delegate = self
        main.contentView = NSHostingView(rootView:Dashboard(model:model,controller:self))
        main.contentMinSize = NSSize(width:430,height:410)
        main.center()
        LegacyWindowLayout.restore(main,name:"PayDanceMacMain",position:"mainPosition",size:"fullSize")
        let miniPanel = MiniPanel(contentRect:NSRect(x:0,y:0,width:176,height:54),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        miniPanel.restoreMainWindow = { [weak self] in self?.showMain() }
        panel = miniPanel
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView = NSHostingView(rootView:Dashboard(model:model,controller:self,mini:true))
        panel.center()
        LegacyWindowLayout.restore(panel,name:"PayDanceMacMini",position:"miniPosition",size:"miniSize")
        status = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName:"clock",accessibilityDescription:"Salary Clock")
        let menu = NSMenu()
        for (name,action) in [("打开主界面",#selector(showMain)),("迷你模式",#selector(showMini)),("迷你窗置顶",#selector(toggleMiniTop)),("退出",#selector(quit))] {
            menu.addItem(withTitle:model.label(name),action:action,keyEquivalent:"").target = self
        }
        menu.delegate = self
        status.button?.toolTip = "Salary Clock"
        let identity = NSMenuItem(title:"Salary Clock", action:nil, keyEquivalent:"")
        menu.insertItem(identity, at:0)
        menu.insertItem(.separator(), at:1)
        model.applyTop = { [weak self] in self?.updatePanel() }
        status.menu = menu
        if model.store.bool(forKey:"mini") { showMini() } else { showMain() }
    }


    func menuNeedsUpdate(_ menu: NSMenu) {
        for (selector,title) in [(#selector(showMain),"打开主界面"),(#selector(showMini),"迷你模式"),(#selector(quit),"退出")] {
            menu.items.first { $0.action == selector }?.title = model.label(title)
        }
        guard let item = menu.items.first(where: { $0.action == #selector(toggleMiniTop) }) else { return }
        item.title = model.label("迷你窗置顶")
        item.state = model.miniIsOnTop ? .on : .off
    }

    @objc private func toggleMiniTop(_ sender: NSMenuItem) {
        model.miniIsOnTop.toggle()
        sender.state = model.miniIsOnTop ? .on : .off
    }

    func updatePanel() {
        let top = model.miniIsOnTop
        panel.collectionBehavior = top ? [.canJoinAllSpaces,.fullScreenAuxiliary,.canJoinAllApplications] : [.fullScreenNone]
        panel.level = top ? .statusBar : .normal
        opacityWindow?.level = panel.level
        guard panel.isVisible else { return }
        if top {
            panel.orderFrontRegardless()
        } else {
            // Lowering the level can leave the panel in front of other normal windows.
            panel.orderBack(nil)
        }
    }
    private var opacityWindow: NSPanel?
    private var outsideClick: Any?
    private var localClick: Any?

    private func hideOpacity() {
        if let outsideClick { NSEvent.removeMonitor(outsideClick) }
        if let localClick { NSEvent.removeMonitor(localClick) }
        outsideClick = nil
        localClick = nil
        if let window = opacityWindow {
            panel.removeChildWindow(window)
            window.orderOut(nil)
        }
        opacityWindow = nil
    }

    func showOpacity() {
        hideOpacity()
        guard let area = panel.screen?.visibleFrame else { return }
        let control = NSHostingView(rootView:OpacityControl(model:model))
        let size = control.fittingSize
        let anchor = panel.frame
        let x = min(max(anchor.midX-size.width/2,area.minX),area.maxX-size.width)
        let above = anchor.maxY + 6
        let y = above + size.height <= area.maxY ? above : max(area.minY,anchor.minY-6-size.height)
        let window = NSPanel(contentRect:NSRect(origin:NSPoint(x:x,y:y),size:size),
                             styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = panel.level
        window.contentView = control
        opacityWindow = window
        panel.addChildWindow(window,ordered:.above)
        window.setFrameOrigin(NSPoint(x:x,y:y))
        window.orderFrontRegardless()
        let mask: NSEvent.EventTypeMask = [.leftMouseDown,.rightMouseDown]
        outsideClick = NSEvent.addGlobalMonitorForEvents(matching:mask) { [weak self] _ in self?.hideOpacity() }
        localClick = NSEvent.addLocalMonitorForEvents(matching:mask.union(.keyDown)) { [weak self] event in
            if event.type == .keyDown {
                if event.keyCode == 53 { self?.hideOpacity(); return nil }
            } else if event.window !== self?.opacityWindow { self?.hideOpacity() }
            return event
        }
    }
    private func removeRecentDockTile() {
        guard model.store.bool(forKey:"restartDockToHideRecent"),
              NSApp.activationPolicy() == .accessory,
              let identifier = Bundle.main.bundleIdentifier,
              let dock = UserDefaults(suiteName:"com.apple.dock"),
              let tiles = dock.array(forKey:"recent-apps") as? [[String:Any]] else { return }
        let remaining = tiles.filter { tile in
            (tile["tile-data"] as? [String:Any])?["bundle-identifier"] as? String != identifier
        }
        guard remaining.count != tiles.count else { return }
        dock.set(remaining,forKey:"recent-apps")
        if dock.synchronize() {
            // Dock caches recent tiles in memory. Relaunch only after removing our own tile.
            if let runningDock = NSRunningApplication.runningApplications(withBundleIdentifier:"com.apple.dock").first {
                kill(runningDock.processIdentifier, SIGTERM)
            }
        }
    }

    @objc func showMini() {
        updatePanel()
        model.store.set(true,forKey:"mini")
        main.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        panel.orderFrontRegardless()
        // Dock writes recent-apps asynchronously after the activation policy changes.
        for delay in [0.0, 0.5, 2.0] {
            DispatchQueue.main.asyncAfter(deadline:.now() + delay) { [weak self] in self?.removeRecentDockTile() }
        }
    }
    @objc func showMain() {
        hideOpacity()
        model.store.set(false,forKey:"mini")
        panel.orderOut(nil)
        NSApp.setActivationPolicy(.regular)
        main.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps:true)
    }
    @objc func showSettings() { showMain(); model.sheet = "设置" }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows:Bool)->Bool { showMain(); return true }
}

struct OpacityControl: View {
    @ObservedObject var model: Model
    @AppStorage("opacity",store:UserDefaults(suiteName:"local.PayDanceMac.Clock.preferences")) var opacity = 0.85
    var body: some View {
        VStack {
            HStack { Text(model.label("透明度")); Spacer(); Text(opacity,format:.percent) }
            Slider(value:$opacity,in:0.1...1,step:0.01).accessibilityLabel(model.label("透明度"))
        }.padding().frame(width:210).background(.regularMaterial,in:RoundedRectangle(cornerRadius:10))
    }
}

struct Dashboard: View {
    @ObservedObject var model: Model
    let controller: Controller
    var mini = false

    @AppStorage("rolling",store:UserDefaults(suiteName:"local.PayDanceMac.Clock.preferences")) var rolling = true
    @AppStorage("symbol",store:UserDefaults(suiteName:"local.PayDanceMac.Clock.preferences")) var symbol = "¥"
    @AppStorage("theme",store:UserDefaults(suiteName:"local.PayDanceMac.Clock.preferences")) var theme = "系统"
    @AppStorage("restartDockToHideRecent",store:UserDefaults(suiteName:"local.PayDanceMac.Clock.preferences")) var restartDockToHideRecent = false
    @AppStorage("opacity",store:UserDefaults(suiteName:"local.PayDanceMac.Clock.preferences")) var opacity = 0.85
    @AppStorage("ready",store:UserDefaults(suiteName:"local.PayDanceMac.Clock.preferences")) var ready = false


    func duration(_ seconds:Double)->String {
        let minutes = max(0, Int(seconds / 60))
        if minutes < 60 { return "\(minutes)m" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }
    var body: some View {
        TimelineView(.periodic(from:.now,by:1)) { time in
            let s = model.snapshot(time.date)
            let amount = symbol + String(format: "%.2f", s.earnedToday)
            if mini {
                Text(amount).font(.title.bold()).monospacedDigit().frame(maxWidth:.infinity,maxHeight:.infinity).background(RoundedRectangle(cornerRadius:14).fill(Color(nsColor:.windowBackgroundColor).opacity(opacity))).contentShape(Rectangle()).accessibilityLabel(model.label("打开主界面") + " " + amount).accessibilityAction { controller.showMain() }.onTapGesture(count:2,perform:controller.showMain).contextMenu {
                    Toggle(model.label("置顶"),isOn:$model.miniIsOnTop)
                    Button(model.label("透明度")) { controller.showOpacity() }
                    Button(model.label("打开主界面"),action:controller.showMain)
                }
            } else {
                VStack(spacing:22) {
                    HStack { Spacer()
                        Button(action:controller.showMini){Image(systemName:"rectangle.compress.vertical")}.accessibilityLabel(model.label("迷你模式"))
                        Button { model.sheet = "设置" } label:{ Image(systemName:"gearshape") }.accessibilityLabel(model.label("设置"))
                    }
                    Spacer()
                    Text(model.label(statusLabel(for: s))).foregroundStyle(.secondary)
                    Text(model.label("今日收入")).foregroundStyle(.secondary)
                    Text(amount).font(.system(size:54,weight:.bold,design:.rounded)).monospacedDigit().contentTransition(rolling ? .numericText() : .identity).animation(rolling ? .easeOut(duration:0.2) : nil,value:amount).onTapGesture(count:2,perform:controller.showMini)
                    VStack(spacing:16) {
                        HStack {
                            metric("已工作", duration(s.elapsedWorkMs / 1000))
                            metric(transitionLabel(for: s.status), s.status == .afterWork ? "100%" : duration(s.nextTransitionMs / 1000))
                            metric("预计收入", symbol + String(format: "%.2f", s.dailySalary))
                        }
                        ProgressView(value: s.progress).tint(.orange)
                    }.padding().background(.regularMaterial,in:RoundedRectangle(cornerRadius:16))
                    Button(model.label("薪资详情")){model.sheet = "薪资详情"}.buttonStyle(.plain)
                    Spacer()
                }.padding()
            }
        }.preferredColorScheme(theme == "系统" ? nil : theme == "深色" ? .dark : .light)
        .onAppear { if !mini && !ready { model.sheet = "首次设置" } }
        .sheet(isPresented:Binding(get:{!mini && !model.sheet.isEmpty},set:{if !$0 {model.sheet = ""}})) {
            VStack {
                Text(model.label(model.sheet)).font(.headline)
                if model.sheet == "首次设置" {
                    Text((model.language == "en" ? ["Preferences","Pay basis","Work schedule"] : ["偏好设置","薪资模式","工作时间"])[model.step])
                    HStack { ForEach(0..<3) { index in Circle().fill(index <= model.step ? Color.accentColor : Color.secondary.opacity(0.3)).frame(width:8,height:8) } }
                }
                if model.sheet == "薪资详情" {
                    Text(model.label(["daily":"日薪","hourly":"时薪"][model.config.salaryType] ?? "月薪")).foregroundStyle(.secondary)
                    let s = model.snapshot(.now)
                    metric("每日", symbol + String(format: "%.2f", s.dailySalary))
                    metric("每小时", symbol + String(format: "%.2f", s.hourlyRate))
                    metric("每分钟", symbol + String(format: "%.2f", s.minuteRate))
                    metric("每秒", symbol + String(format: "%.4f", s.secondRate))
                } else {
                    Form {
                        if model.sheet != "首次设置" || model.step == 1 {
                        Picker(model.label("薪资模式"),selection:$model.config.salaryType){Text(model.label("月薪")).tag("monthly");Text(model.label("日薪")).tag("daily");Text(model.label("时薪")).tag("hourly")}
                        if model.config.salaryType == "monthly" {
                            TextField(model.label("月薪"),value:$model.config.monthlySalary,format:.number)
                            TextField(model.label("每月工作天数"),value:$model.config.workDaysPerMonth,format:.number)
                        } else if model.config.salaryType == "daily" {TextField(model.label("日薪"),value:$model.config.dailySalary,format:.number)}
                        else {TextField(model.label("时薪"),value:$model.config.hourlyRate,format:.number)}
                        TextField(model.label("货币符号"),text:$symbol)
                        }
                        if model.sheet != "首次设置" || model.step == 2 {
                        HStack { ForEach(1...7,id:\.self){day in
                            let value = day % 7
                            Toggle((model.language == "en" ? ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"] : ["日","一","二","三","四","五","六"])[value],isOn:Binding(get:{model.config.workdays.contains(value)},set:{on in
                                model.config.workdays.removeAll{$0 == value}
                                if on { model.config.workdays.append(value) }
                            })).toggleStyle(.button)
                        }}
                        TextField(model.label("上班时间"),text:$model.config.startTime)
                        TextField(model.label("下班时间"),text:$model.config.endTime)
                        Toggle(model.label("午休"),isOn:$model.config.enableLunchBreak)
                        if model.config.enableLunchBreak {TextField(model.label("午休开始"),text:$model.config.lunchStart);TextField(model.label("午休结束"),text:$model.config.lunchEnd)}
                        }
                        if model.sheet != "首次设置" || model.step == 0 {
                        LabeledContent(model.label("语言")) {
                            Picker(model.label("语言"), selection: $model.language) {
                                Text("中文").tag("zh-CN")
                                Text("English").tag("en")
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                        if model.sheet != "首次设置" { Button(model.label("重新配置")) { model.step = 0; model.sheet = "首次设置" } }
                        Toggle(model.label("金额滚动动画"),isOn:$rolling)
                        Picker(model.label("外观"),selection:$theme){ForEach(["系统","浅色","深色"],id:\.self){Text(model.label($0))}}
                        Toggle(model.label("迷你窗置顶"),isOn:$model.miniIsOnTop)
                        Slider(value:$opacity,in:0.1...1){Text(model.label("迷你窗透明度"))}
                        Toggle(model.language == "en" ? "Restart Dock to hide the recent app in mini mode" : "迷你模式下重启 Dock 以隐藏最近使用图标", isOn:$restartDockToHideRecent)
                        Text(model.language == "en" ? "When Salary Clock appears in recent apps, the Dock briefly disappears and returns." : "当 Salary Clock 出现在最近使用列表中时，Dock 会短暂消失后重新出现。").font(.caption)
                        Toggle(model.label("登录时启动"),isOn:Binding(get:{model.login},set:{ enabled in
                            do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                            catch { model.error = error.localizedDescription }
                            model.login = SMAppService.mainApp.status == .enabled
                        }))
                        if !model.error.isEmpty {Text(model.error)}
                        if model.sheet == "设置" {
                            let version = Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? ""
                            Text("Salary Clock " + version)
                            Link("Based on PayDance © 2026 Mr.Baoboer · AGPL-3.0-only", destination:URL(string:"https://github.com/MrBaoboer/PayDance")!)
                        }
                        }
                    }.formStyle(.grouped)
                }
                let invalidConfig = model.sheet != "薪资详情" && model.snapshot(.now).status == .invalidConfig
                if invalidConfig { Text(model.language == "en" ? "Check the pay amount, workdays and shift times (HH:mm)." : "请检查薪资、工作日和上下班时间（HH:mm）。").foregroundStyle(.red) }
                HStack { if model.sheet == "首次设置" && model.step > 0 { Button(model.language == "en" ? "Back" : "上一步"){model.step -= 1} }; if model.sheet == "首次设置" && model.step < 2 { Button(model.language == "en" ? "Next" : "下一步"){ model.step += 1 } } else { Button(model.label("完成")){ready = true; model.sheet = ""}.disabled(invalidConfig) } }
            }.padding().frame(width:470,height:model.sheet == "薪资详情" ? 320 : 610)
        }
    }
    private func statusLabel(for snapshot: SalarySnapshot) -> String {
        switch snapshot.status {
        case .working: return snapshot.isNightWork ? "正在夜班" : "工作中"
        case .afterWork: return snapshot.isNightWork ? "夜班已完成" : "已下班"
        case .restDay: return "休息日"
        case .beforeWork: return "上班前"
        case .lunchBreak: return "午休中"
        case .invalidConfig: return "请检查设置"
        }
    }

    private func transitionLabel(for status: SalaryStatus) -> String {
        switch status {
        case .working: return "距离下班"
        case .afterWork: return "今日完成"
        case .restDay: return "休息日"
        case .beforeWork: return "距离上班"
        case .lunchBreak: return "距离复工"
        case .invalidConfig: return "配置异常"
        }
    }

    func metric(_ title:String,_ value:String)->some View { VStack {Text(model.label(title)).font(.caption).foregroundStyle(.secondary);Text(value).monospacedDigit().bold()}.frame(maxWidth:.infinity) }
}
