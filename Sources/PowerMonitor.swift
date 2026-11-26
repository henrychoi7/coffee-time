import Foundation
import IOKit.ps
import notify

/// Receives powerd notifications on the main queue instead of waiting for a poll.
@MainActor final class PowerMonitor {
    private var tokens: [Int32] = []
    private(set) var isActive = false
    private let notificationNames: [String]
    private let snapshot: () -> PowerSnapshot?
    private let onChange: (PowerSnapshot) -> Void

    init(notificationNames: [String] = [kIOPSNotifyPowerSource, kIOPSNotifyTimeRemaining],
         snapshot: @escaping () -> PowerSnapshot? = PowerController.snapshot,
         onChange: @escaping (PowerSnapshot) -> Void) {
        self.notificationNames = notificationNames
        self.snapshot = snapshot
        self.onChange = onChange
    }

    @discardableResult func start() -> Bool {
        stop()
        for name in notificationNames {
            var token: Int32 = 0
            let result = notify_register_dispatch(name, &token, .main) { [weak self] _ in
                // notify_register_dispatch was explicitly registered on DispatchQueue.main.
                MainActor.assumeIsolated {
                    guard let self, self.isActive else { return }
                    self.refresh()
                }
            }
            guard result == NOTIFY_STATUS_OK else {
                stop()
                return false
            }
            tokens.append(token)
        }
        isActive = !tokens.isEmpty
        // Close the gap between the initial snapshot and registering the observer.
        refresh()
        return isActive
    }

    func refresh() {
        guard let current = snapshot() else { return }
        onChange(current)
    }

    func stop() {
        isActive = false
        tokens.forEach { notify_cancel($0) }
        tokens.removeAll()
    }

    deinit { tokens.forEach { notify_cancel($0) } }
}
