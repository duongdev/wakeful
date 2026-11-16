import IOKit

public enum Hardware {
    /// Whether this Mac has a lid. Desktop Macs have no clamshell state.
    public static let hasLid: Bool = {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        defer { IOObjectRelease(service) }
        return IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0) != nil
    }()
}
