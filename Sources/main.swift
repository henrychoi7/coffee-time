import AppKit
import SwiftUI
import UserNotifications
import notify

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let model = CoffeeModel()
    lazy var updates = UpdateManager(model: model)
    var status: NSStatusItem!
    var mainWindow: NSWindow?
    var miniWindow: NSPanel?
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        installMenu()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.target = self
        status.button?.action = #selector(statusClicked)
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        model.statusChanged = { [weak self] in self?.updateStatus() }
        updateStatus()
        if model.settings.showWindowAtLaunch { showMain() }
        if model.settings.notifications { model.enableNotifications(true) }
        if !model.restoreAfterUpdate() {
            model.handleSystemStartup(bootIdentifier: SystemStartup.bootIdentifier())
        }
        updates.start()
    }
    func installMenu() {
        let menu = NSMenu()
        let app = NSMenuItem(); let submenu = NSMenu()
        let show = NSMenuItem(title: L10n.text("Open Coffee Time"), action: #selector(showMain), keyEquivalent: "0"); show.target = self
        submenu.addItem(show)
        let update = NSMenuItem(title: L10n.text("Check for Updates…"), action: #selector(checkForUpdates), keyEquivalent: "")
        update.target = self; submenu.addItem(update)
        submenu.addItem(.separator())
        submenu.addItem(NSMenuItem(title: L10n.text("Quit Coffee Time"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        app.submenu = submenu; menu.addItem(app)
        let file = NSMenuItem(title: L10n.text("File"), action: nil, keyEquivalent: "")
        let fileMenu = NSMenu(title: L10n.text("File"))
        // A nil target routes Close to the focused window through the responder chain.
        fileMenu.addItem(NSMenuItem(title: L10n.text("Close Window"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        file.submenu = fileMenu; menu.addItem(file)
        let edit = NSMenuItem(title: L10n.text("Edit"), action: nil, keyEquivalent: ""); let editMenu = NSMenu(title: L10n.text("Edit"))
        for (title, selector, key) in [(L10n.text("Undo"), Selector(("undo:")), "z"), (L10n.text("Cut"), #selector(NSText.cut(_:)), "x"), (L10n.text("Copy"), #selector(NSText.copy(_:)), "c"), (L10n.text("Paste"), #selector(NSText.paste(_:)), "v"), (L10n.text("Select All"), #selector(NSText.selectAll(_:)), "a")] {
            editMenu.addItem(NSMenuItem(title: title, action: selector, keyEquivalent: key))
        }
        edit.submenu = editMenu; menu.addItem(edit); NSApp.mainMenu = menu
    }
    @objc func statusClicked() {
        if (NSApp.currentEvent?.type == .rightMouseUp || NSApp.currentEvent?.modifierFlags.contains(.control) == true), model.settings.rightClickCycles {
            model.setMode(model.mode.next); return
        }
        let menu = NSMenu()
        let header = NSMenuItem(title: "Coffee Time · \(model.mode.title)", action: nil, keyEquivalent: ""); header.isEnabled = false; menu.addItem(header)
        menu.addItem(.separator())
        for mode in CoffeeMode.allCases {
            let item = NSMenuItem(title: "\(mode.title) — \(mode == .buzz ? L10n.text("Keep the display awake") : mode == .doze ? L10n.text("Keep your Mac awake") : L10n.text("Allow sleep"))", action: #selector(selectMode(_:)), keyEquivalent: "")
            item.representedObject = mode.rawValue; item.target = self; item.state = model.mode == mode ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        if let session = model.session, let left = model.remaining {
            let item = NSMenuItem(title: L10n.format("%@ until %@ · Cancel timer", clockText(left), session.target.title), action: #selector(cancelTimer), keyEquivalent: ""); item.target = self; menu.addItem(item)
        }
        let timerMenu = NSMenu()
        for minutes in [15, 30, 60, 120] {
            let item = NSMenuItem(title: L10n.format("Off in %ld min", minutes), action: #selector(timerPreset(_:)), keyEquivalent: ""); item.tag = minutes; item.target = self; timerMenu.addItem(item)
        }
        if !model.settings.recentTimers.isEmpty {
            timerMenu.addItem(.separator())
            for preset in model.settings.recentTimers {
                let item = NSMenuItem(title: L10n.format("Recent: %ld min → %@", preset.minutes, preset.target.title), action: #selector(recentPreset(_:)), keyEquivalent: ""); item.representedObject = preset; item.target = self; timerMenu.addItem(item)
            }
        }
        let timer = NSMenuItem(title: L10n.text("Switch timer"), action: nil, keyEquivalent: ""); timer.submenu = timerMenu; menu.addItem(timer)
        menu.addItem(.separator())
        for (title, action) in [(L10n.text("Controls & Settings…"), #selector(showMain)), (L10n.text("Mini Window"), #selector(showMini))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item)
        }
        menu.addItem(.separator())
        let updateItem = NSMenuItem(title: L10n.text("Check for Updates…"), action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self; updateItem.isEnabled = updates.canCheckForUpdates
        menu.addItem(updateItem)
        menu.addItem(NSMenuItem(title: L10n.text("Quit Coffee Time"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        status.menu = menu; status.button?.performClick(nil); status.menu = nil
    }
    func updateStatus() {
        guard let button = status?.button else { return }
        button.image = NSImage(systemSymbolName: model.mode == .off ? "cup.and.saucer" : model.mode.symbol, accessibilityDescription: "Coffee Time \(model.mode.title)")
        button.image?.isTemplate = true
        button.title = model.settings.showCountdown ? model.remaining.map { " " + clockText($0) } ?? "" : ""
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        button.toolTip = "Coffee Time · \(model.mode.title)\n\(model.mode.detail)" + (model.remaining.map { L10n.format("\nTime remaining: %@", clockText($0)) } ?? "")
    }
    @objc func selectMode(_ sender: NSMenuItem) { if let raw = sender.representedObject as? String, let mode = CoffeeMode(rawValue: raw) { model.setMode(mode) } }
    @objc func timerPreset(_ sender: NSMenuItem) { model.startTimer(minutes: sender.tag, target: .off) }
    @objc func recentPreset(_ sender: NSMenuItem) { if let preset = sender.representedObject as? TimerPreset { model.startTimer(minutes: preset.minutes, target: preset.target) } }
    @objc func checkForUpdates() { updates.checkForUpdates() }
    @objc func cancelTimer() { model.cancelTimer() }
    @objc func showMain() {
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 650), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Coffee Time"; window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: CoffeeView(model: model, updates: updates, showMini: { [weak self] in self?.showMini() }))
            window.center(); mainWindow = window
        }
        miniWindow?.orderOut(nil)
        NSApp.activate(ignoringOtherApps: true); mainWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func showMini() {
        if miniWindow == nil {
            let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 225, height: 101), styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel], backing: .buffered, defer: false)
            window.title = "Coffee Time"; window.isReleasedWhenClosed = false; window.level = .floating; window.hidesOnDeactivate = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.contentView = NSHostingView(rootView: MiniView(model: model, expand: { [weak self] in self?.showMain() }))
            window.center(); miniWindow = window
        }
        mainWindow?.orderOut(nil); miniWindow?.orderFrontRegardless()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showMain(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { model.shutdown() }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) { completionHandler([.banner, .list]) }
}

if CommandLine.arguments.contains("--power-smoke-test") {
    let power = PowerController()
    do {
        for mode in [CoffeeMode.buzz, .doze, .off] {
            try power.apply(mode)
            print("\(mode.title): \(power.assertionIDs.count) assertions")
            fflush(stdout)
            Thread.sleep(forTimeInterval: 3)
        }
        exit(0)
    } catch { fputs("\(error)\n", stderr); exit(1) }
}
if CommandLine.arguments.contains("--integration-test") {
    MainActor.assumeIsolated {
        let suiteName = "local.coffeetime.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = CoffeeModel(defaults: defaults, startsMonitoring: false)
        var notifications: [UNNotificationRequest] = []
        model.notificationSink = { notifications.append($0) }
        defer { model.shutdown() }
        let korean = CommandLine.arguments.contains("--expect-korean")
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            checks += 1
            guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
        }
        check(Bundle.main.preferredLocalizations.first == (korean ? "ko" : "en"), "app language matches system preferences or falls back to English")
        check(L10n.text("Controls") == (korean ? "컨트롤" : "Controls"), "control tab localization")
        check(L10n.text("Check for Updates…") == (korean ? "업데이트 확인…" : "Check for Updates…"), "update menu localization")
        check(L10n.format("Battery at %ld%% or below", 20) == (korean ? "배터리 20% 이하" : "Battery at 20% or below"), "battery percentage formatting")
        check(L10n.format("Switch to %@ in %ld min", "Off", 30) == (korean ? "30분 후 Off로 전환합니다." : "Switch to Off in 30 min"), "localized format argument order")
        check(L10n.text("Missing translation fallback") == "Missing translation fallback", "missing translation falls back to its English key")
        model.startTimer(minutes: 0, target: .off)
        check(model.error == (korean ? "타이머는 1분부터 7일까지 설정할 수 있습니다." : "Set a timer between one minute and seven days."), "validation error localization")
        model.error = nil
        check(model.mode == .off, "fresh launch off")
        check(model.setMode(.buzz), "Buzz assertions acquired")
        check(notifications.last?.content.title == (korean ? "Buzz 모드" : "Buzz mode") && notifications.last?.content.subtitle == (korean ? "Off → Buzz · 직접 변경" : "Off → Buzz · Manual change"), "manual mode change posts banner content")
        model.startTimer(minutes: 1, target: .doze)
        check(model.mode == .buzz && model.session != nil, "timer preserves current mode")
        model.tick(at: Date().addingTimeInterval(61))
        check(model.mode == .doze && model.session == nil, "timer actually changes power mode")
        check(notifications.last?.content.subtitle == (korean ? "Buzz → Doze · 타이머 완료" : "Buzz → Doze · Timer finished"), "timer posts transition reason")
        model.startTimer(minutes: 1, target: .buzz)
        model.setMode(.off)
        check(model.session == nil, "manual selection cancels timer")
        model.settings.safetyUsesIdle = false
        model.settings.safetyMinutes = 15
        model.setMode(.buzz)
        model.startTimer(minutes: 60, target: .buzz)
        model.tick(at: Date().addingTimeInterval(901))
        check(model.mode == .doze && model.session == nil, "safety cancels timer and releases display")
        check(notifications.last?.content.subtitle.contains((korean ? "화면 보호 자동 전환" : "Display protection")) == true, "safety posts notification")
        model.startTimer(minutes: 0, target: .off)
        check(model.session == nil && model.error != nil, "invalid timer rejected")
        for value in [15, 30, 60, 120, 30] { model.startTimer(minutes: value, target: .off) }
        check(model.settings.recentTimers.map(\.minutes) == [30, 120, 60], "three unique recent timers")
        model.cancelTimer()
        var rule = CoffeeRule(); rule.trigger = .appLaunched; rule.appBundleID = "test.target"; rule.mode = .buzz
        model.settings.rules = [rule]
        model.appEvent(.appLaunched, bundleID: "other.app")
        check(model.mode == .doze, "other app ignored")
        model.appEvent(.appLaunched, bundleID: "test.target")
        check(model.mode == .buzz, "matching app applies rule")
        check(notifications.last?.content.subtitle.contains((korean ? "다른 앱 실행" : "Another app launches")) == true, "app rule posts notification")
        rule.mode = .off; rule.delayMinutes = 5
        model.settings.rules.append(rule)
        model.appEvent(.appLaunched, bundleID: "test.target")
        check(model.mode == .buzz && model.session?.target == .off, "last matching rule starts delayed change")
        let restored = CoffeeModel(defaults: defaults, startsMonitoring: false)
        check(restored.settings.rules.count == 2 && restored.mode == .off && restored.session == nil, "settings persist, active sessions do not")
        restored.shutdown()
        model.setMode(.off)
        check(notifications.last?.content.title == (korean ? "Off 모드" : "Off mode"), "Off transition posts notification")
        check(Set(notifications.map(\.identifier)).count == notifications.count, "each transition has a unique notification")
        let notificationCount = notifications.count
        model.settings.notifications = false
        model.setMode(.doze)
        model.setMode(.off)
        check(notifications.count == notificationCount, "notification opt-out respected")
        // Exercise real Darwin notification delivery with a private test key, never a system key.
        model.settings.rules = []
        model.settings.notifications = true
        let battery = PowerSnapshot(onAC: false, batteryPercent: 75)
        let adapter = PowerSnapshot(onAC: true, batteryPercent: 75)
        var simulatedPower = battery
        let notificationName = "local.coffeetime.tests.power.\(UUID().uuidString)"
        var events = 0
        let monitor = PowerMonitor(notificationNames: [notificationName], snapshot: { simulatedPower }) { current in
            events += 1
            model.receivePowerSnapshot(current)
        }
        check(monitor.start(), "power notification registration succeeds")
        defer { monitor.stop() }
        var connect = CoffeeRule(); connect.trigger = .powerConnected; connect.mode = .buzz
        var disconnect = CoffeeRule(); disconnect.trigger = .powerDisconnected; disconnect.mode = .off
        model.settings.rules = [connect, disconnect]
        func deliver(_ snapshot: PowerSnapshot) {
            simulatedPower = snapshot
            let before = events
            check(notify_post(notificationName) == NOTIFY_STATUS_OK, "test power event posted")
            let deadline = Date().addingTimeInterval(2)
            while events == before && Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            }
            check(events > before, "power event received without timer tick")
        }
        let eventStart = Date()
        deliver(adapter)
        check(model.mode == .buzz && model.session == nil, "connecting immediately activates Buzz")
        print(String(format: "Power event to mode change: %.0f ms (simulated snapshot, real notify delivery)", Date().timeIntervalSince(eventStart) * 1000))
        let afterConnect = notifications.count
        deliver(adapter)
        check(notifications.count == afterConnect, "duplicate power notification does not repeat rule")
        deliver(battery)
        check(model.mode == .off, "disconnecting immediately switches Off")
        deliver(adapter)
        deliver(battery)
        check(model.mode == .off && notifications.count == afterConnect + 3, "rapid alternating power events retain both edges")
        model.settings.rules[0].delayMinutes = 2
        deliver(adapter)
        check(model.mode == .off && model.session?.target == .buzz, "explicit rule delay still respected")
        model.settings.rules = []
        model.cancelTimer()
        monitor.stop()
        check(!monitor.isActive, "power monitor unregisters on shutdown")
        let systemMonitor = PowerMonitor { _ in }
        check(systemMonitor.start(), "actual macOS power notification keys register")
        systemMonitor.stop()
        let bootID = SystemStartup.bootIdentifier()
        check(bootID != nil && bootID == SystemStartup.bootIdentifier(), "real boot identity is available and stable")
        model.handleSystemStartup(bootIdentifier: "test-boot-a")
        var startup = CoffeeRule(); startup.trigger = .systemStarted; startup.mode = .doze
        model.settings.rules = [startup]
        model.handleSystemStartup(bootIdentifier: "test-boot-a")
        check(model.mode == .off, "adding a startup rule does not replay the current boot")
        model.handleSystemStartup(bootIdentifier: "test-boot-b")
        check(model.mode == .doze && notifications.last?.content.subtitle.contains((korean ? "시스템 시작 시" : "System startup")) == true, "new boot applies startup mode with notification")
        model.setMode(.off)
        model.handleSystemStartup(bootIdentifier: "test-boot-b")
        check(model.mode == .off, "startup event runs only once per boot")
        let relaunched = CoffeeModel(defaults: defaults, startsMonitoring: false)
        relaunched.notificationSink = { notifications.append($0) }
        relaunched.handleSystemStartup(bootIdentifier: "test-boot-b")
        check(relaunched.mode == .off && relaunched.settings.rules.first?.trigger == .systemStarted, "boot marker and startup rule survive app relaunch")
        relaunched.shutdown()
        model.settings.rules[0].mode = .buzz
        model.settings.rules[0].delayMinutes = 3
        model.handleSystemStartup(bootIdentifier: "test-boot-c")
        check(model.mode == .off && model.session?.target == .buzz, "startup rule supports a delayed transition")
        let originalDeadline = model.session?.deadline
        model.handleSystemStartup(bootIdentifier: "test-boot-c")
        check(model.session?.deadline == originalDeadline, "duplicate startup does not restart timer")
        model.tick(at: Date().addingTimeInterval(181))
        check(model.mode == .buzz && model.session == nil, "delayed startup mode executes")
        model.setMode(.off)
        model.settings.rules[0].enabled = false
        model.handleSystemStartup(bootIdentifier: "test-boot-d")
        check(model.mode == .off && model.session == nil, "disabled startup rule ignored")
        startup.mode = .buzz
        var laterStartup = startup; laterStartup.id = UUID(); laterStartup.mode = .doze
        model.settings.rules = [startup, laterStartup]
        model.handleSystemStartup(bootIdentifier: "test-boot-e")
        check(model.mode == .doze, "last enabled startup rule wins")
        model.setMode(.off)
        model.handleSystemStartup(bootIdentifier: nil)
        model.handleSystemStartup(bootIdentifier: "")
        model.tick()
        check(model.mode == .off, "unknown boot and routine ticks do not trigger startup rule")
        model.settings.rules = []
        model.setMode(.buzz)
        model.startTimer(minutes: 30, target: .off)
        let savedDeadline = model.session?.deadline
        let updateDate = Date()
        model.prepareForUpdateRelaunch(targetBuild: "1100", at: updateDate, boot: "update-test-boot")
        let updatedModel = CoffeeModel(defaults: defaults, startsMonitoring: false)
        updatedModel.notificationSink = { _ in }
        defer { updatedModel.shutdown() }
        check(updatedModel.restoreAfterUpdate(build: "1100", at: updateDate.addingTimeInterval(2), boot: "update-test-boot"), "successful update resumes once")
        check(updatedModel.mode == .buzz && updatedModel.session?.deadline == savedDeadline, "update keeps active mode and timer deadline")
        check(!updatedModel.restoreAfterUpdate(build: "1100", boot: "update-test-boot"), "resume state cannot replay")
        model.prepareForUpdateRelaunch(targetBuild: "1100", at: updateDate, boot: "update-test-boot")
        check(!updatedModel.restoreAfterUpdate(build: "1099", at: updateDate, boot: "update-test-boot"), "failed update does not resume in the old version")
        model.prepareForUpdateRelaunch(targetBuild: "1100", at: updateDate, boot: "update-test-boot")
        check(!updatedModel.restoreAfterUpdate(build: "1100", at: updateDate, boot: "another-boot"), "update state does not survive reboot")
        model.prepareForUpdateRelaunch(targetBuild: "1100", at: updateDate, boot: "update-test-boot")
        check(!updatedModel.restoreAfterUpdate(build: "1100", at: updateDate.addingTimeInterval(601), boot: "update-test-boot"), "stale update state expires")
        model.startTimer(minutes: 1, target: .off)
        model.prepareForUpdateRelaunch(targetBuild: "1100", at: updateDate, boot: "update-test-boot")
        check(updatedModel.restoreAfterUpdate(build: "1100", at: updateDate.addingTimeInterval(65), boot: "update-test-boot") && updatedModel.mode == .off && updatedModel.session == nil, "timer that expires during an update completes on relaunch")
        model.setMode(.off)
        print("\(checks)/\(checks) integration checks passed")
    }
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    // An accessory app stays available in the menu bar even when all windows are closed.
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
