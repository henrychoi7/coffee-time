import AppKit
import Combine
import Sparkle

@MainActor final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticUpdatesEnabled = true
    @Published private(set) var status = "업데이트를 확인할 준비가 됐습니다."
    private var controller: SPUStandardUpdaterController!
    private weak var model: CoffeeModel?
    private var pendingVersion: String?

    init(model: CoffeeModel) {
        self.model = model
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .combineLatest(controller.updater.publisher(for: \.automaticallyDownloadsUpdates))
            .map { $0 && $1 }.assign(to: &$automaticUpdatesEnabled)
    }

    func start() {
        controller.startUpdater()
        if controller.updater.automaticallyChecksForUpdates && controller.updater.canCheckForUpdates {
            controller.updater.checkForUpdatesInBackground()
        }
    }

    func checkForUpdates() { controller.checkForUpdates(nil) }

    func setAutomaticUpdates(_ enabled: Bool) {
        controller.updater.automaticallyDownloadsUpdates = enabled
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        pendingVersion = item.versionString
        status = "새 버전 \(item.displayVersionString)을 찾았습니다."
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) { status = "현재 사용할 수 있는 새 업데이트가 없습니다." }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        pendingVersion = nil
        let failure = error as NSError
        if failure.domain == SUSparkleErrorDomain && failure.code == Int(SUError.noUpdateError.rawValue) {
            status = "현재 사용할 수 있는 새 업데이트가 없습니다."
        } else {
            status = "업데이트를 완료하지 못했습니다. 네트워크 연결을 확인한 뒤 다시 시도해 주세요."
            NSLog("Coffee Time update failed: %@", failure)
        }
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        pendingVersion = item.versionString
        status = "업데이트를 설치하고 있습니다."
    }

    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
                 immediateInstallationBlock install: @escaping () -> Void) -> Bool {
        pendingVersion = item.versionString
        status = "업데이트를 설치한 뒤 다시 실행합니다."
        // Schedule outside the delegate callback so Sparkle can finish preparing the install.
        DispatchQueue.main.async { install() }
        return true
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        guard let pendingVersion else { return }
        model?.prepareForUpdateRelaunch(targetBuild: pendingVersion)
    }
}
