import Foundation
import IOKit.pwr_mgt
import IOKit.ps

final class PowerController {
    private(set) var assertionIDs: [IOPMAssertionID] = []
    func apply(_ mode: CoffeeMode) throws {
        var newIDs: [IOPMAssertionID] = []
        let types: [String] = switch mode {
        case .buzz: [kIOPMAssertionTypePreventUserIdleSystemSleep, kIOPMAssertionTypePreventUserIdleDisplaySleep]
        case .doze: [kIOPMAssertionTypePreventUserIdleSystemSleep]
        case .off: []
        }
        for type in types {
            var id: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), "Coffee Time — \(mode.title)" as CFString, &id)
            guard result == kIOReturnSuccess else {
                newIDs.forEach { IOPMAssertionRelease($0) }
                throw NSError(domain: "CoffeeTime.Power", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "잠자기 방지를 활성화하지 못했습니다 (\(result))."])
            }
            newIDs.append(id)
        }
        release()
        assertionIDs = newIDs
    }
    func release() { assertionIDs.forEach { IOPMAssertionRelease($0) }; assertionIDs.removeAll() }
    deinit { release() }
    static func snapshot() -> PowerSnapshot? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in sources {
            guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  (d[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
            let capacity = d[kIOPSCurrentCapacityKey] as? Int
            let maxCapacity = d[kIOPSMaxCapacityKey] as? Int ?? 100
            let percent = capacity.map { maxCapacity > 0 ? min(100, max(0, $0 * 100 / maxCapacity)) : 0 }
            return PowerSnapshot(onAC: (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue, batteryPercent: percent)
        }
        return PowerSnapshot(onAC: true, batteryPercent: nil)
    }
}
