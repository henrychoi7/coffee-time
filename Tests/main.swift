import Foundation
var failures = 0
var total = 0
func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    total += 1
    if !condition() { failures += 1; print("FAIL: \(name)") }
}
let now = Date(timeIntervalSince1970: 1000)
let timer = SessionTimer(deadline: now.addingTimeInterval(60), target: .off)
check(!timer.isDue(at: now), "timer does not fire early")
check(timer.isDue(at: now.addingTimeInterval(60)), "timer fires at boundary")
check(timer.isDue(at: now.addingTimeInterval(1000)), "timer fires after sleep")
check(timer.remaining(at: now.addingTimeInterval(1000)) == 0, "no negative countdown")
check(clockText(3599.1) == "1:00:00", "hour rollover")
check(clockText(1.2) == "00:02", "countdown rounds up")
check(clockText(-1) == "00:00", "countdown clamps negative")
check(CoffeeMode.off.next == .buzz && CoffeeMode.buzz.next == .doze && CoffeeMode.doze.next == .off, "mode cycle")
let ac = PowerSnapshot(onAC: true, batteryPercent: 70)
let battery = PowerSnapshot(onAC: false, batteryPercent: 70)
let low = PowerSnapshot(onAC: false, batteryPercent: 20)
let lower = PowerSnapshot(onAC: false, batteryPercent: 19)
var rule = CoffeeRule()
check(!RulesEngine.powerMatches(rule, previous: nil, current: battery), "initial snapshot is not an event")
check(RulesEngine.powerMatches(rule, previous: ac, current: battery), "disconnect event")
check(!RulesEngine.powerMatches(rule, previous: battery, current: battery), "no duplicate disconnect")
rule.trigger = .powerConnected
check(RulesEngine.powerMatches(rule, previous: battery, current: ac), "connect event")
rule.trigger = .lowBattery
check(RulesEngine.powerMatches(rule, previous: battery, current: low), "threshold crossing")
check(!RulesEngine.powerMatches(rule, previous: low, current: lower), "low battery only fires once")
check(!RulesEngine.powerMatches(rule, previous: low, current: PowerSnapshot(onAC: true, batteryPercent: 19)), "charging does not trigger low battery")
check(RulesEngine.powerMatches(rule, previous: ac, current: low), "unplugging low battery")
check(!RulesEngine.powerMatches(rule, previous: battery, current: PowerSnapshot(onAC: false, batteryPercent: nil)), "missing battery is safe")
rule.enabled = false
check(!RulesEngine.powerMatches(rule, previous: battery, current: low), "disabled rule")
var settings = CoffeeSettings(); settings.rules = [rule]; settings.recentTimers = [TimerPreset(minutes: 30, target: .doze)]
let encoded = try JSONEncoder().encode(settings)
let decoded = try JSONDecoder().decode(CoffeeSettings.self, from: encoded)
check(decoded.rules == settings.rules && decoded.recentTimers == settings.recentTimers, "settings roundtrip")
print("\(total - failures)/\(total) checks passed")
exit(failures == 0 ? 0 : 1)
