import Foundation

enum CoffeeMode: String, Codable, CaseIterable, Identifiable {
    case buzz, doze, off
    var id: String { rawValue }
    var title: String { switch self { case .buzz: "Buzz"; case .doze: "Doze"; case .off: "Off" } }
    var symbol: String { switch self { case .buzz: "cup.and.saucer.fill"; case .doze: "moon.zzz.fill"; case .off: "power" } }
    var detail: String { switch self {
    case .buzz: L10n.text("Keeps your Mac and display awake.")
    case .doze: L10n.text("Keeps your Mac awake while letting the display sleep.")
    case .off: L10n.text("Uses your normal macOS sleep settings.")
    } }
    var next: CoffeeMode { switch self { case .off: .buzz; case .buzz: .doze; case .doze: .off } }
}
enum RuleTrigger: String, Codable, CaseIterable, Identifiable {
    case powerConnected, powerDisconnected, lowBattery, appLaunched, appQuit, systemStarted
    var id: String { rawValue }
    var title: String { switch self {
    case .powerConnected: L10n.text("Power adapter connected"); case .powerDisconnected: L10n.text("Power adapter disconnected")
    case .lowBattery: L10n.text("Battery falls to a set level"); case .appLaunched: L10n.text("Another app launches"); case .appQuit: L10n.text("Another app quits")
    case .systemStarted: L10n.text("System startup")
    } }
}
struct CoffeeRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var enabled = true
    var trigger: RuleTrigger = .powerDisconnected
    var mode: CoffeeMode = .off
    var delayMinutes: Int = 0
    var batteryThreshold: Int = 20
    var appBundleID: String = ""
    var appName: String = ""
}
struct TimerPreset: Codable, Equatable, Identifiable {
    var minutes: Int
    var target: CoffeeMode
    var id: String { "\(minutes)-\(target.rawValue)" }
}
struct CoffeeSettings: Codable {
    var rightClickCycles = true
    var showCountdown = true
    var safetyEnabled = true
    var safetyMinutes = 120
    var safetyUsesIdle = true
    var notifications = true
    var showWindowAtLaunch = true
    var rules: [CoffeeRule] = []
    var recentTimers: [TimerPreset] = []
}
struct SessionTimer {
    let deadline: Date
    let target: CoffeeMode
    func remaining(at date: Date) -> TimeInterval { max(0, deadline.timeIntervalSince(date)) }
    func isDue(at date: Date) -> Bool { date >= deadline }
}
struct PowerSnapshot: Equatable {
    let onAC: Bool
    let batteryPercent: Int?
}
enum RulesEngine {
    static func powerMatches(_ rule: CoffeeRule, previous: PowerSnapshot?, current: PowerSnapshot) -> Bool {
        guard rule.enabled, let previous else { return false }
        switch rule.trigger {
        case .powerConnected: return !previous.onAC && current.onAC
        case .powerDisconnected: return previous.onAC && !current.onAC
        case .lowBattery:
            guard !current.onAC, let level = current.batteryPercent else { return false }
            return level <= rule.batteryThreshold && (previous.onAC || (previous.batteryPercent ?? 101) > rule.batteryThreshold)
        default: return false
        }
    }
}
func clockText(_ seconds: TimeInterval) -> String {
    let value = max(0, Int(ceil(seconds)))
    if value >= 3600 { return String(format: "%d:%02d:%02d", value / 3600, (value % 3600) / 60, value % 60) }
    return String(format: "%02d:%02d", value / 60, value % 60)
}

struct UpdateResumeState: Codable {
    let targetBuild: String
    let bootIdentifier: String
    let createdAt: Date
    let mode: CoffeeMode
    let deadline: Date?
    let timerTarget: CoffeeMode?
    let buzzStarted: Date?

    func canRestore(build: String, boot: String?, at date: Date) -> Bool {
        let age = date.timeIntervalSince(createdAt)
        return targetBuild == build && bootIdentifier == boot && age >= 0 && age <= 600
    }
}
