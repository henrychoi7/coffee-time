import AppKit
import SwiftUI
import UserNotifications
import ServiceManagement

@MainActor final class CoffeeModel: ObservableObject {
    @Published private(set) var mode: CoffeeMode = .off
    @Published var settings: CoffeeSettings { didSet { save() } }
    @Published private(set) var session: SessionTimer?
    @Published private(set) var now = Date()
    @Published private(set) var power: PowerSnapshot?
    @Published var message = "준비됐어요. 커피 한 잔처럼 가볍게 시작하세요."
    @Published var error: String?
    @Published var loginEnabled = false
    private let controller = PowerController()
    private let defaults: UserDefaults
    private var tickTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var buzzStarted: Date?
    private var powerMonitor: PowerMonitor?
    var statusChanged: (() -> Void)?
    // Tests can inspect notifications without sending them to Notification Center.
    var notificationSink: ((UNNotificationRequest) -> Void)?
    var remaining: TimeInterval? { session.map { $0.remaining(at: now) } }
    var loginNeedsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    init(defaults: UserDefaults = .standard, startsMonitoring: Bool = true) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "CoffeeTime.Settings.v1"), let stored = try? JSONDecoder().decode(CoffeeSettings.self, from: data) { settings = stored }
        else { settings = CoffeeSettings() }
        power = PowerController.snapshot()
        refreshLogin()
        guard startsMonitoring else { return }
        let monitor = PowerMonitor { [weak self] current in self?.receivePowerSnapshot(current) }
        powerMonitor = monitor
        monitor.start()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if let tickTimer { RunLoop.main.add(tickTimer, forMode: .common) }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let id = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
                let trigger: RuleTrigger = notification.name == NSWorkspace.didLaunchApplicationNotification ? .appLaunched : .appQuit
                Task { @MainActor in self?.appEvent(trigger, bundleID: id) }
            })
        }
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
                self?.powerMonitor?.refresh()
            }
        })
    }
    func save() {
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: "CoffeeTime.Settings.v1") }
        statusChanged?()
    }
    @discardableResult func setMode(_ newMode: CoffeeMode, reason: String = "직접 변경", cancelTimer: Bool = true) -> Bool {
        let previousMode = mode
        do { try controller.apply(newMode) }
        catch { self.error = error.localizedDescription; return false }
        if cancelTimer { session = nil }
        mode = newMode
        buzzStarted = newMode == .buzz ? Date() : nil
        message = "\(reason) · \(newMode.title)"
        statusChanged?()
        notifyMode(newMode, previous: previousMode, reason: reason)
        return true
    }
    func startTimer(minutes: Int, target: CoffeeMode) {
        guard (1...10080).contains(minutes) else { error = "타이머는 1분부터 7일까지 설정할 수 있습니다."; return }
        session = SessionTimer(deadline: Date().addingTimeInterval(Double(minutes) * 60), target: target)
        now = Date()
        let preset = TimerPreset(minutes: minutes, target: target)
        settings.recentTimers.removeAll { $0 == preset }
        settings.recentTimers.insert(preset, at: 0)
        settings.recentTimers = Array(settings.recentTimers.prefix(3))
        message = "\(minutes)분 후 \(target.title)로 전환합니다."
        statusChanged?()
    }
    func cancelTimer() { session = nil; message = "타이머를 취소했습니다."; statusChanged?() }
    func tick(at date: Date = Date()) {
        now = date
        if let active = session, active.isDue(at: now) {
            session = nil
            _ = setMode(active.target, reason: "타이머 완료")
        }
        if mode == .buzz, settings.safetyEnabled, let began = buzzStarted {
            let elapsed = now.timeIntervalSince(began)
            let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)
            let duration = settings.safetyUsesIdle ? min(elapsed, idle) : elapsed
            if duration >= Double(settings.safetyMinutes) * 60 {
                _ = setMode(.doze, reason: "화면 보호 자동 전환")
            }
        }
        // Only fall back to the existing 1-second tick if notification registration failed.
        if let powerMonitor, !powerMonitor.isActive { powerMonitor.refresh() }
        statusChanged?()
    }
    func receivePowerSnapshot(_ current: PowerSnapshot) {
        let matching = settings.rules.filter { RulesEngine.powerMatches($0, previous: power, current: current) }
        // Update before applying a rule so repeated OS notifications cannot fire it again.
        power = current
        if let winner = matching.last { apply(winner) }
    }
    func appEvent(_ trigger: RuleTrigger, bundleID: String?) {
        guard let bundleID else { return }
        if let rule = settings.rules.last(where: { $0.enabled && $0.trigger == trigger && $0.appBundleID == bundleID }) { apply(rule) }
    }
    func handleSystemStartup(bootIdentifier: String?) {
        guard let bootIdentifier, !bootIdentifier.isEmpty else { return }
        let key = "CoffeeTime.LastObservedBoot.v1"
        guard defaults.string(forKey: key) != bootIdentifier else { return }
        // Record every boot even without a rule. Adding/enabling a rule later must not
        // retrospectively turn a normal app relaunch into a system-start event.
        defaults.set(bootIdentifier, forKey: key)
        if let rule = settings.rules.last(where: { $0.enabled && $0.trigger == .systemStarted }) {
            apply(rule)
        }
    }
    func apply(_ rule: CoffeeRule) {
        if rule.delayMinutes > 0 { startTimer(minutes: rule.delayMinutes, target: rule.mode) }
        else { _ = setMode(rule.mode, reason: rule.trigger.title) }
    }
    func enableNotifications(_ enabled: Bool) {
        settings.notifications = enabled
        if enabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, error in
                Task { @MainActor in
                    if !granted { self.settings.notifications = false; self.error = error?.localizedDescription ?? "시스템 설정 → 알림 → Coffee Time에서 알림을 허용한 뒤 다시 켜 주세요." }
                }
            }
        }
    }
    private func notifyMode(_ mode: CoffeeMode, previous: CoffeeMode, reason: String) {
        guard settings.notifications else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(mode.title) 모드"
        content.subtitle = previous == mode ? reason : "\(previous.title) → \(mode.title) · \(reason)"
        content.body = mode.detail
        content.threadIdentifier = "coffee-time-mode-changes"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        if let notificationSink { notificationSink(request); return }
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            guard let error else { return }
            Task { @MainActor in self?.error = "모드는 변경됐지만 알림을 표시하지 못했습니다: \(error.localizedDescription)" }
        }
    }
    func refreshLogin() { loginEnabled = SMAppService.mainApp.status == .enabled }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            refreshLogin()
            if loginNeedsApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch { self.error = error.localizedDescription; refreshLogin() }
    }
    func shutdown() {
        tickTimer?.invalidate()
        powerMonitor?.stop()
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
        controller.release()
    }
}
