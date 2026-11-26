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
                    Text("잠깐의 커피, 계속되는 작업").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: showMini) { Image(systemName: "pip.enter") }.help("항상 위에 표시되는 미니 창")
            }.padding(24)
            Picker("페이지", selection: $page) {
                Text("컨트롤").tag(0); Text("자동 규칙").tag(1); Text("설정").tag(2)
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
            Button("확인") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private var control: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("지금 필요한 만큼 깨어 있기").font(.headline); Spacer(); Text(model.mode.title.uppercased()).font(.caption.bold()).foregroundStyle(coffee) }
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
                    Label("전환 타이머", systemImage: "timer").font(.headline)
                    Spacer()
                    if let remaining = model.remaining { Text(clockText(remaining)).font(.system(.title3, design: .monospaced).bold()).foregroundStyle(coffee) }
                }
                if let session = model.session {
                    HStack { Text("종료 시 \(session.target.title)로 전환").foregroundStyle(.secondary); Spacer(); Button("타이머 취소") { model.cancelTimer() } }
                } else {
                    HStack {
                        TextField("분", value: $minutes, format: .number).frame(width: 60).textFieldStyle(.roundedBorder)
                        Text("분 후")
                        Picker("전환 모드", selection: $target) { ForEach(CoffeeMode.allCases) { Text($0.title).tag($0) } }.labelsHidden().frame(width: 95)
                        Spacer()
                        Button("시작") { model.startTimer(minutes: minutes, target: target) }.buttonStyle(.borderedProminent)
                    }
                    HStack(spacing: 8) {
                        ForEach([15, 30, 60, 120], id: \.self) { value in Button(value < 60 ? "\(value)분" : "\(value / 60)시간") { minutes = value }.buttonStyle(.bordered) }
                    }
                    Text("현재 모드를 유지하다가 지정한 모드로 바뀝니다.").font(.caption).foregroundStyle(.secondary)
                }
                if !model.settings.recentTimers.isEmpty {
                    HStack { Text("최근").font(.caption).foregroundStyle(.secondary)
                        ForEach(model.settings.recentTimers) { preset in Button("\(preset.minutes)분 → \(preset.target.title)") { model.startTimer(minutes: preset.minutes, target: preset.target) }.font(.caption).buttonStyle(.borderless) }
                    }
                }
            }.padding(16).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        }
    }
    private var rules: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("상황에 맞춰 자동으로").font(.headline); Spacer(); Button { model.settings.rules.append(CoffeeRule()) } label: { Label("규칙 추가", systemImage: "plus") } }
            Text("이벤트가 발생할 때 실행합니다. 동시에 일치하면 아래쪽 규칙이 우선하며, 새 동작은 기존 타이머를 바꿉니다.").font(.caption).foregroundStyle(.secondary)
            if model.settings.rules.contains(where: { $0.trigger == .systemStarted && $0.enabled }), !model.loginEnabled {
                HStack {
                    Text("시작 규칙을 자동으로 실행하려면 로그인 자동 실행을 켜 주세요.").font(.caption).foregroundStyle(.secondary)
                    Button("자동 실행 켜기") { model.setLogin(true) }
                }
            }
            if model.settings.rules.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bolt.badge.clock").font(.system(size: 38)).foregroundStyle(coffee)
                    Text("작업에 맞는 루틴을 만들어 보세요.").font(.headline)
                    Text("시스템 시작, 전원 연결, 배터리 잔량,\n앱 실행과 종료에 맞춰 모드를 변경합니다.").multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button("첫 번째 규칙 만들기") { model.settings.rules.append(CoffeeRule()) }.buttonStyle(.borderedProminent)
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
                    Toggle("화면 보호 자동 전환", isOn: $model.settings.safetyEnabled).font(.headline)
                    Text("Buzz를 오래 켜 두었을 때 Doze로 바꾸고 진행 중인 타이머를 취소합니다.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Picker("기준", selection: $model.settings.safetyUsesIdle) { Text("입력이 없을 때").tag(true); Text("Buzz 시작 후").tag(false) }.frame(width: 220)
                        Picker("시간", selection: $model.settings.safetyMinutes) {
                            ForEach([15, 30, 60, 120, 240, 480], id: \.self) { Text("\($0)분").tag($0) }
                        }
                    }.disabled(!model.settings.safetyEnabled)
                }.padding(10)
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 15) {
                    Text("내 방식대로").font(.headline)
                    Toggle("메뉴 막대 우클릭으로 Off → Buzz → Doze 전환", isOn: $model.settings.rightClickCycles)
                    Toggle("메뉴 막대에 남은 시간 표시", isOn: $model.settings.showCountdown)
                    Toggle("실행할 때 컨트롤 창 열기", isOn: $model.settings.showWindowAtLaunch)
                    Toggle("모드 변경 및 타이머 완료 알림", isOn: Binding(get: { model.settings.notifications }, set: { model.enableNotifications($0) }))
                    Text("모드가 바뀌면 화면 오른쪽 배너와 알림 센터에 표시합니다.").font(.caption).foregroundStyle(.secondary)
                    Toggle("로그인 시 자동 실행", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                    if model.loginNeedsApproval { Button("시스템 설정에서 로그인 항목 허용") { SMLoginSettings.open() } }
                }.padding(10)
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("앱 업데이트").font(.headline)
                    Toggle("새 버전을 자동으로 받아 설치", isOn: Binding(get: { updates.automaticUpdatesEnabled }, set: { updates.setAutomaticUpdates($0) }))
                    Text("실행할 때와 매시간 새 버전을 확인합니다. 설치 후 다시 실행하며 모드와 타이머를 이어갑니다.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text(updates.status).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("업데이트 확인…") { updates.checkForUpdates() }.disabled(!updates.canCheckForUpdates)
                    }
                }.padding(10)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Coffee Time \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · Apple Silicon").font(.subheadline.bold())
                Text("앱을 종료하면 잠자기 방지도 해제됩니다. 기본 시작 모드는 Off이며, 시스템 시작 규칙이 있으면 적용합니다. Mac 덮개 닫기나 직접 잠자기는 막지 않습니다.").font(.caption).foregroundStyle(.secondary)
                Text("화면 잠금 정책과 시스템 설정은 그대로 유지됩니다.").font(.caption).foregroundStyle(.secondary)
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
                Toggle("사용", isOn: $rule.enabled).toggleStyle(.switch).labelsHidden()
                Picker("조건", selection: $rule.trigger) { ForEach(RuleTrigger.allCases) { Text($0.title).tag($0) } }.labelsHidden()
                Button(role: .destructive, action: remove) { Image(systemName: "trash") }.buttonStyle(.borderless).help("규칙 삭제")
            }
            if rule.trigger == .lowBattery { Stepper("배터리 \(rule.batteryThreshold)% 이하", value: $rule.batteryThreshold, in: 5...95, step: 5) }
            if rule.trigger == .systemStarted {
                Text("재부팅 후 Coffee Time이 처음 실행될 때 한 번 적용합니다. 로그인 자동 실행을 켜 두세요. 앱 재실행이나 절전 복귀에는 적용하지 않습니다.").font(.caption).foregroundStyle(.secondary)
            }
            if rule.trigger == .appLaunched || rule.trigger == .appQuit {
                HStack { Text(rule.appName.isEmpty ? "앱을 선택해 주세요" : rule.appName).lineLimit(1); Spacer(); Button("앱 선택…", action: chooseApp) }
                if !rule.appBundleID.isEmpty { Text(rule.appBundleID).font(.caption2).foregroundStyle(.secondary) }
            }
            HStack {
                Picker("동작", selection: $rule.mode) { ForEach(CoffeeMode.allCases) { Text($0.title).tag($0) } }.frame(width: 150)
                Spacer()
                TextField("지연", value: $rule.delayMinutes, format: .number).frame(width: 52).textFieldStyle(.roundedBorder)
                    .onChange(of: rule.delayMinutes) { new in rule.delayMinutes = min(10080, max(0, new)) }
                Text("분 후 전환").foregroundStyle(.secondary)
            }
            Text("0분이면 즉시 변경합니다.").font(.caption).foregroundStyle(.secondary)
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
            Button { model.setMode(model.mode.next) } label: { Image(systemName: model.mode.symbol).font(.system(size: 24)).foregroundStyle(coffee) }.buttonStyle(.plain).help("모드 전환")
            VStack(alignment: .leading, spacing: 3) {
                Text(model.mode.title).font(.headline)
                Text(model.remaining.map(clockText) ?? "Coffee Time").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: expand) { Image(systemName: "arrow.up.left.and.arrow.down.right") }.buttonStyle(.plain).help("컨트롤 창 열기")
        }.padding(18).frame(width: 225, height: 65).background(canvas)
    }
}
import ServiceManagement
enum SMLoginSettings { static func open() { SMAppService.openSystemSettingsLoginItems() } }
