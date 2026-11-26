import SwiftUI
import AppKit

private let coffee = Color(red: 0.78, green: 0.47, blue: 0.25)
private let canvas = Color(nsColor: .windowBackgroundColor)

struct CoffeeView: View {
    @ObservedObject var model: CoffeeModel
    @ObservedObject var updates: UpdateManager
    var showMini: () -> Void
    @State private var page = 0
    @State private var minutes = 30
    @State private var target = CoffeeMode.off
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                Image(systemName: "cup.and.saucer.fill").font(.system(size: 30)).foregroundStyle(coffee)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Coffee Time").font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text(L10n.text("A coffee break for you. More time for your Mac.")).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: showMini) { Image(systemName: "pip.enter") }.help(L10n.text("Show the floating mini window"))
            }.padding(24)
            Picker(L10n.text("Page"), selection: $page) {
                Text(L10n.text("Controls")).tag(0); Text(L10n.text("Rules")).tag(1); Text(L10n.text("Settings")).tag(2)
            }.pickerStyle(.segmented).labelsHidden().padding(.horizontal, 24).padding(.bottom, 18)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if page == 0 { control }
                    else if page == 1 { rules }
                    else { preferences }
                }.padding(.horizontal, 24).padding(.bottom, 24)
            }
            Divider()
            HStack {
                Circle().fill(model.mode == .off ? Color.secondary : coffee).frame(width: 6, height: 6)
                Text(model.message).lineLimit(1)
                Spacer(minLength: 8)
                if let power = model.power {
                    Image(systemName: power.onAC ? "powerplug.fill" : "battery.75percent")
                    if let percent = power.batteryPercent { Text("\(percent)%") }
                }
            }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.vertical, 13)
        }
        .frame(width: 540, height: 650).background(canvas).tint(coffee)
        .alert("Coffee Time", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button(L10n.text("OK")) { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private var control: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text(L10n.text("Stay awake on your terms")).font(.headline); Spacer(); Text(model.mode.title.uppercased()).font(.caption.bold()).foregroundStyle(coffee) }
            ForEach(CoffeeMode.allCases) { mode in
                Button { model.setMode(mode) } label: {
                    HStack(spacing: 15) {
                        Image(systemName: mode.symbol).font(.system(size: 23)).frame(width: 34).foregroundStyle(model.mode == mode ? coffee : .secondary)
                        VStack(alignment: .leading, spacing: 4) { Text(mode.title).font(.system(size: 17, weight: .semibold)); Text(mode.detail).font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Image(systemName: model.mode == mode ? "checkmark.circle.fill" : "circle").foregroundStyle(model.mode == mode ? coffee : .secondary.opacity(0.4))
                    }.padding(15).frame(maxWidth: .infinity, alignment: .leading)
                    .background(model.mode == mode ? coffee.opacity(0.10) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(model.mode == mode ? coffee.opacity(0.5) : .clear))
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Label(L10n.text("Switch timer"), systemImage: "timer").font(.headline)
                    Spacer()
                    if let remaining = model.remaining { Text(clockText(remaining)).font(.system(.title3, design: .monospaced).bold()).foregroundStyle(coffee) }
                }
                if let session = model.session {
                    HStack { Text(L10n.format("Switch to %@ when the timer ends", session.target.title)).foregroundStyle(.secondary); Spacer(); Button(L10n.text("Cancel timer")) { model.cancelTimer() } }
                } else {
                    HStack {
                        TextField(L10n.text("Minutes"), value: $minutes, format: .number).frame(width: 60).textFieldStyle(.roundedBorder)
                        Text(L10n.text("min, then"))
                        Picker(L10n.text("Switch to"), selection: $target) { ForEach(CoffeeMode.allCases) { Text($0.title).tag($0) } }.labelsHidden().frame(width: 95)
                        Spacer()
                        Button(L10n.text("Start")) { model.startTimer(minutes: minutes, target: target) }.buttonStyle(.borderedProminent)
                    }
                    HStack(spacing: 8) {
                        ForEach([15, 30, 60, 120], id: \.self) { value in Button(value < 60 ? L10n.format("%ld min", value) : L10n.format("%ld hr", value / 60)) { minutes = value }.buttonStyle(.bordered) }
                    }
                    Text(L10n.text("Keeps the current mode until the timer ends, then switches to your chosen mode.")).font(.caption).foregroundStyle(.secondary)
                }
                if !model.settings.recentTimers.isEmpty {
                    HStack { Text(L10n.text("Recent")).font(.caption).foregroundStyle(.secondary)
                        ForEach(model.settings.recentTimers) { preset in Button(L10n.format("%ld min → %@", preset.minutes, preset.target.title)) { model.startTimer(minutes: preset.minutes, target: preset.target) }.font(.caption).buttonStyle(.borderless) }
                    }
                }
            }.padding(16).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        }
    }
    private var rules: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text(L10n.text("Let your Mac handle the switch")).font(.headline); Spacer(); Button { model.settings.rules.append(CoffeeRule()) } label: { Label(L10n.text("Add rule"), systemImage: "plus") } }
            Text(L10n.text("Rules run when an event occurs. The last matching rule takes priority and replaces any active timer.")).font(.caption).foregroundStyle(.secondary)
            if model.settings.rules.contains(where: { $0.trigger == .systemStarted && $0.enabled }), !model.loginEnabled {
                HStack {
                    Text(L10n.text("Enable Launch at Login to run startup rules automatically.")).font(.caption).foregroundStyle(.secondary)
                    Button(L10n.text("Enable Launch at Login")) { model.setLogin(true) }
                }
            }
            if model.settings.rules.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bolt.badge.clock").font(.system(size: 38)).foregroundStyle(coffee)
                    Text(L10n.text("Build a routine that works for you")).font(.headline)
                    Text(L10n.text("Switch modes at startup, when power or battery levels change,\nor when another app opens or quits.")).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button(L10n.text("Create your first rule")) { model.settings.rules.append(CoffeeRule()) }.buttonStyle(.borderedProminent)
                }.frame(maxWidth: .infinity).padding(.vertical, 50)
            }
            ForEach($model.settings.rules) { $rule in
                RuleEditor(rule: $rule, remove: { model.settings.rules.removeAll { $0.id == rule.id } })
            }
        }
    }
    private var preferences: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox {
                VStack(alignment: .leading, spacing: 13) {
                    Toggle(L10n.text("Display protection"), isOn: $model.settings.safetyEnabled).font(.headline)
                    Text(L10n.text("Switch from Buzz to Doze after a while and cancel any active timer.")).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Picker(L10n.text("Based on"), selection: $model.settings.safetyUsesIdle) { Text(L10n.text("Idle time")).tag(true); Text(L10n.text("Time in Buzz")).tag(false) }.frame(width: 220)
                        Picker(L10n.text("Duration"), selection: $model.settings.safetyMinutes) {
                            ForEach([15, 30, 60, 120, 240, 480], id: \.self) { Text(L10n.format("%ld min", $0)).tag($0) }
                        }
                    }.disabled(!model.settings.safetyEnabled)
                }.padding(10)
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 15) {
                    Text(L10n.text("Make it yours")).font(.headline)
                    Toggle(L10n.text("Right-click the menu bar icon to cycle modes"), isOn: $model.settings.rightClickCycles)
                    Toggle(L10n.text("Show the countdown in the menu bar"), isOn: $model.settings.showCountdown)
                    Toggle(L10n.text("Show the control window at launch"), isOn: $model.settings.showWindowAtLaunch)
                    Toggle(L10n.text("Notify me when the mode changes"), isOn: Binding(get: { model.settings.notifications }, set: { model.enableNotifications($0) }))
                    Text(L10n.text("Mode changes appear as banners and in Notification Center.")).font(.caption).foregroundStyle(.secondary)
                    Toggle(L10n.text("Launch at Login"), isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                    if model.loginNeedsApproval { Button(L10n.text("Allow the login item in System Settings")) { SMLoginSettings.open() } }
                }.padding(10)
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.text("App updates")).font(.headline)
                    Toggle(L10n.text("Download and install updates automatically"), isOn: Binding(get: { updates.automaticUpdatesEnabled }, set: { updates.setAutomaticUpdates($0) }))
                    Text(L10n.text("Checks at launch and every hour. After installing an update, the app restarts with your mode and timer intact.")).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text(updates.status).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(L10n.text("Check for Updates…")) { updates.checkForUpdates() }.disabled(!updates.canCheckForUpdates)
                    }
                }.padding(10)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Coffee Time \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · Apple Silicon").font(.subheadline.bold())
                Text(L10n.text("Quitting releases sleep prevention. The app normally starts in Off unless a startup rule applies. Closing the lid or choosing Sleep still puts your Mac to sleep.")).font(.caption).foregroundStyle(.secondary)
                Text(L10n.text("Screen lock policies and system settings stay unchanged.")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
struct RuleEditor: View {
    @Binding var rule: CoffeeRule
    let remove: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Toggle(L10n.text("Enabled"), isOn: $rule.enabled).toggleStyle(.switch).labelsHidden()
                Picker(L10n.text("Trigger"), selection: $rule.trigger) { ForEach(RuleTrigger.allCases) { Text($0.title).tag($0) } }.labelsHidden()
                Button(role: .destructive, action: remove) { Image(systemName: "trash") }.buttonStyle(.borderless).help(L10n.text("Delete rule"))
            }
            if rule.trigger == .lowBattery { Stepper(L10n.format("Battery at %ld%% or below", rule.batteryThreshold), value: $rule.batteryThreshold, in: 5...95, step: 5) }
            if rule.trigger == .systemStarted {
                Text(L10n.text("Runs once when Coffee Time first opens after a reboot. Enable Launch at Login to run it automatically. Relaunching the app or waking from sleep does not trigger it.")).font(.caption).foregroundStyle(.secondary)
            }
            if rule.trigger == .appLaunched || rule.trigger == .appQuit {
                HStack { Text(rule.appName.isEmpty ? L10n.text("Choose an app") : rule.appName).lineLimit(1); Spacer(); Button(L10n.text("Choose App…"), action: chooseApp) }
                if !rule.appBundleID.isEmpty { Text(rule.appBundleID).font(.caption2).foregroundStyle(.secondary) }
            }
            HStack {
                Picker(L10n.text("Mode"), selection: $rule.mode) { ForEach(CoffeeMode.allCases) { Text($0.title).tag($0) } }.frame(width: 150)
                Spacer()
                TextField(L10n.text("Delay"), value: $rule.delayMinutes, format: .number).frame(width: 52).textFieldStyle(.roundedBorder)
                    .onChange(of: rule.delayMinutes) { new in rule.delayMinutes = min(10080, max(0, new)) }
                Text(L10n.text("min delay")).foregroundStyle(.secondary)
            }
            Text(L10n.text("Use 0 for an immediate switch.")).font(.caption).foregroundStyle(.secondary)
        }.padding(15).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
    }
    private func chooseApp() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.applicationBundle]; panel.directoryURL = URL(fileURLWithPath: "/Applications"); panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return }
        rule.appBundleID = id; rule.appName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? url.deletingPathExtension().lastPathComponent
    }
}
struct MiniView: View {
    @ObservedObject var model: CoffeeModel
    let expand: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Button { model.setMode(model.mode.next) } label: { Image(systemName: model.mode.symbol).font(.system(size: 24)).foregroundStyle(coffee) }.buttonStyle(.plain).help(L10n.text("Switch mode"))
            VStack(alignment: .leading, spacing: 3) {
                Text(model.mode.title).font(.headline)
                Text(model.remaining.map(clockText) ?? "Coffee Time").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: expand) { Image(systemName: "arrow.up.left.and.arrow.down.right") }.buttonStyle(.plain).help(L10n.text("Open the control window"))
        }.padding(18).frame(width: 225, height: 65).background(canvas)
    }
}
import ServiceManagement
enum SMLoginSettings { static func open() { SMAppService.openSystemSettingsLoginItems() } }
