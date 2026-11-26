import Foundation
import Darwin

/// A kernel-issued identifier changes on reboot, but stays stable across app launches and sleep.
enum SystemStartup {
    static func bootIdentifier() -> String? {
        var size = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0) == 0, size > 1 else { return nil }
        var bytes = [CChar](repeating: 0, count: size)
        let result = bytes.withUnsafeMutableBytes {
            sysctlbyname("kern.bootsessionuuid", $0.baseAddress, &size, nil, 0)
        }
        guard result == 0 else { return nil }
        let identifier = String(cString: bytes)
        return identifier.isEmpty ? nil : identifier
    }
}
