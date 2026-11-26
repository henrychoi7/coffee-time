import AppKit
import Combine
import Sparkle

@MainActor final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticUpdatesEnabled = true
    @Published private(set) var status = L10n.text("Ready to check for updates")
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
        status = L10n.format("Version %@ is available", item.displayVersionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) { status = L10n.text("You’re up to date") }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        pendingVersion = nil
        let failure = error as NSError
        if failure.domain == SUSparkleErrorDomain && failure.code == Int(SUError.noUpdateError.rawValue) {
            status = L10n.text("You’re up to date")
        } else {
            status = L10n.text("The update could not be completed. Check your connection and try again.")
            NSLog("Coffee Time update failed: %@", failure)
        }
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        pendingVersion = item.versionString
        status = L10n.text("Installing the update…")
    }

    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
                 immediateInstallationBlock install: @escaping () -> Void) -> Bool {
        pendingVersion = item.versionString
        status = L10n.text("Installing the update and restarting…")
        // Schedule outside the delegate callback so Sparkle can finish preparing the install.
        DispatchQueue.main.async { install() }
        return true
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        guard let pendingVersion else { return }
        model?.prepareForUpdateRelaunch(targetBuild: pendingVersion)
    }
}
