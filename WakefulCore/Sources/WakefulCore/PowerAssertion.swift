import IOKit.pwr_mgt

/// IOKit power assertion. `PreventUserIdleDisplaySleep` keeps the display on;
/// `PreventUserIdleSystemSleep` lets the display sleep. Neither stops lid-close sleep.
@MainActor
public final class PowerAssertion: AssertionHolding {
    private var id: IOPMAssertionID?
    private let name: String

    public init(name: String = "Wakeful is keeping your Mac awake") {
        self.name = name
    }

    public func set(_ kind: AssertionKind?) {
        if let id {
            IOPMAssertionRelease(id)
            self.id = nil
        }
        guard let kind else { return }
        let type = kind == .display ? kIOPMAssertPreventUserIdleDisplaySleep : kIOPMAssertPreventUserIdleSystemSleep
        var newID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), name as CFString, &newID)
        if result == kIOReturnSuccess {
            id = newID
        } else {
            Log.shared.error("IOPMAssertionCreateWithName failed: \(result)")
        }
    }
}
