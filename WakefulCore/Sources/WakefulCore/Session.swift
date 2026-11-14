import Foundation

/// The kind of power assertion a session needs right now.
public enum AssertionKind: Equatable, Sendable {
    /// Keep the system and the display awake.
    case display
    /// Keep the system awake; the display may sleep.
    case system
}

/// Holds at most one power assertion. The real one wraps IOKit; tests use a fake.
@MainActor
public protocol AssertionHolding: AnyObject {
    /// Replaces any held assertion with `kind`, or releases it when `kind` is nil.
    func set(_ kind: AssertionKind?)
}

/// What a session does while the screen is locked.
public enum LockBehavior: String, CaseIterable, Sendable {
    /// No change: keep the Mac (and the display, if set) awake.
    case keepAwake
    /// Let the display sleep; keep the Mac awake.
    case allowDisplaySleep
    /// Release the assertion; the Mac may sleep. The session keeps running.
    case allowSleep
}

public enum EndReason: Equatable, Sendable {
    case user
    case expired
    case switchedToBattery
}

/// The single source of truth for "active". All controls (menu, URL scheme, later CLI and Shortcuts) call it.
/// Time is passed in, so the logic is pure and testable. The app calls `update(now:)` when a deadline passes.
@MainActor
public final class Session {
    public private(set) var isActive = false
    /// When the session ends. Nil while inactive or when the session is indefinite.
    public private(set) var endsAt: ContinuousClock.Instant?
    /// The duration the running session was started (or last changed) with. Nil while inactive.
    public private(set) var duration: SessionDuration?

    public var keepDisplayAwake: Bool { didSet { reconcile() } }
    public var lockBehavior: LockBehavior { didSet { reconcile() } }
    public var deactivateOnBattery: Bool

    public var isScreenLocked = false { didSet { reconcile() } }

    /// Called whenever `isActive` or `endsAt` changes.
    public var onChange: (() -> Void)?
    /// Called once per session end.
    public var onEnd: ((EndReason) -> Void)?

    private let assertion: AssertionHolding
    private var isOnBattery = false

    public init(
        assertion: AssertionHolding,
        keepDisplayAwake: Bool = DefaultSettings.keepDisplayAwake,
        lockBehavior: LockBehavior = DefaultSettings.lockBehavior,
        deactivateOnBattery: Bool = DefaultSettings.deactivateOnBattery
    ) {
        self.assertion = assertion
        self.keepDisplayAwake = keepDisplayAwake
        self.lockBehavior = lockBehavior
        self.deactivateOnBattery = deactivateOnBattery
    }

    /// Starts a session, or replaces the duration of the running one.
    public func activate(_ duration: SessionDuration, now: ContinuousClock.Instant) {
        isActive = true
        self.duration = duration
        endsAt = duration.timeInterval.map { now.advanced(by: .seconds($0)) }
        reconcile()
        onChange?()
    }

    public func deactivate(_ reason: EndReason = .user) {
        guard isActive else { return }
        isActive = false
        endsAt = nil
        duration = nil
        reconcile()
        onChange?()
        onEnd?(reason)
    }

    public func toggle(_ duration: SessionDuration, now: ContinuousClock.Instant) {
        if isActive { deactivate() } else { activate(duration, now: now) }
    }

    /// Adds (or with a negative value, removes) time from a timed session.
    /// Returns false when off or indefinite. Removing more than is left turns the session off.
    @discardableResult
    public func adjust(by seconds: TimeInterval, now: ContinuousClock.Instant) -> Bool {
        guard isActive, let endsAt else { return false }
        let newEnd = endsAt.advanced(by: .seconds(seconds))
        guard newEnd > now else {
            deactivate()
            return true
        }
        self.endsAt = newEnd
        let left = now.duration(to: newEnd).components
        duration = .seconds(Double(left.seconds) + Double(left.attoseconds) / 1e18)
        onChange?()
        return true
    }

    public func remaining(now: ContinuousClock.Instant) -> Duration? {
        endsAt.map { max(.zero, now.duration(to: $0)) }
    }

    /// Ends the session if its deadline has passed.
    public func update(now: ContinuousClock.Instant) {
        if let endsAt, endsAt <= now { deactivate(.expired) }
    }

    /// Ends the session only on a switch from AC to battery, not when the app starts on battery.
    public func powerSourceChanged(onBattery: Bool) {
        let switched = onBattery && !isOnBattery
        isOnBattery = onBattery
        if switched && deactivateOnBattery { deactivate(.switchedToBattery) }
    }

    private var heldKind: AssertionKind?

    /// Brings the held assertion in line with the state. Touches the assertion only when the needed kind changes.
    private func reconcile() {
        let awake: AssertionKind = keepDisplayAwake ? .display : .system
        let needed: AssertionKind? =
            if !isActive { nil }
            else if !isScreenLocked { awake }
            else {
                switch lockBehavior {
                case .keepAwake: awake
                case .allowDisplaySleep: .system
                case .allowSleep: nil
                }
            }
        guard needed != heldKind else { return }
        heldKind = needed
        assertion.set(needed)
    }
}
