import IOKit.pwr_mgt

/// IOKit power assertion. `PreventUserIdleDisplaySleep` keeps the display on;
/// `PreventUserIdleSystemSleep` lets the display sleep. Neither stops lid-close sleep.
@MainActor
public final class PowerAssertion: AssertionHolding {
    private(set) var heldID: IOPMAssertionID?
    private var kind: AssertionKind?
    private let name: String

    public init(name: String = "Wakeful is keeping your Mac awake") {
        self.name = name
    }

    public func set(_ kind: AssertionKind?) {
        if let heldID {
            IOPMAssertionRelease(heldID)
            self.heldID = nil
        }
        self.kind = kind
        guard let kind else { return }
        let type = kind == .display ? kIOPMAssertPreventUserIdleDisplaySleep : kIOPMAssertPreventUserIdleSystemSleep
        var newID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), name as CFString, &newID)
        if result == kIOReturnSuccess {
            heldID = newID
        } else {
            Log.shared.error("IOPMAssertionCreateWithName failed: \(result)")
        }
    }

    /// Re-creates the assertion if one is wanted but the system no longer has it, for example after
    /// sleep or a user switch. Returns true when it had to re-create it.
    @discardableResult
    public func ensureHeld() -> Bool {
        guard let kind else { return false }
        if let heldID, IOPMAssertionCopyProperties(heldID)?.takeRetainedValue() != nil { return false }
        Log.shared.error("Power assertion was lost; re-creating it")
        heldID = nil
        set(kind)
        return true
    }
}
