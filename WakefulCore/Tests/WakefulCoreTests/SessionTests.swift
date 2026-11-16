import Testing
@testable import WakefulCore

@MainActor
final class FakeAssertion: AssertionHolding {
    var calls: [AssertionKind?] = []
    var current: AssertionKind? { calls.last ?? nil }
    func set(_ kind: AssertionKind?) { calls.append(kind) }
}

@MainActor
struct SessionTests {
    let t0 = ContinuousClock.now
    let fake = FakeAssertion()

    @Test func activateHoldsDisplayAssertionAndSetsDeadline() {
        let session = Session(assertion: fake)
        session.activate(.minutes(30), now: t0)
        #expect(session.isActive)
        #expect(fake.current == .display)
        #expect(session.remaining(now: t0) == .seconds(1800))
    }

    @Test func indefiniteHasNoDeadline() {
        let session = Session(assertion: fake)
        session.activate(.indefinite, now: t0)
        #expect(session.endsAt == nil)
        session.update(now: t0.advanced(by: .seconds(100_000)))
        #expect(session.isActive)
    }

    @Test func displayOverrideAppliesToTheSession() {
        let session = Session(assertion: fake, keepDisplayAwake: true)
        session.activate(.hours(1), now: t0, keepDisplayAwake: false)
        #expect(fake.current == .system)
        #expect(!session.keepsDisplayAwake)
        session.activate(.hours(2), now: t0)
        #expect(fake.current == .system, "changing the duration keeps the session's choice")
        session.activate(.hours(2), now: t0, keepDisplayAwake: true)
        #expect(fake.current == .display, "a new choice replaces it")
    }

    @Test func displayOverrideEndsWithTheSession() {
        let session = Session(assertion: fake, keepDisplayAwake: false)
        session.activate(.indefinite, now: t0, keepDisplayAwake: true)
        #expect(fake.current == .display)
        session.deactivate()
        session.activate(.indefinite, now: t0)
        #expect(fake.current == .system)
    }

    @Test func displayOverrideYieldsToASettingChange() {
        let session = Session(assertion: fake, keepDisplayAwake: true)
        session.activate(.indefinite, now: t0, keepDisplayAwake: false)
        session.keepDisplayAwake = true
        #expect(fake.current == .system, "setting the same value is not a change")
        session.keepDisplayAwake = false
        session.keepDisplayAwake = true
        #expect(fake.current == .display)
    }

    @Test func displayOverrideStillFollowsLockBehavior() {
        let session = Session(assertion: fake, keepDisplayAwake: false, lockBehavior: .allowSleep)
        session.activate(.indefinite, now: t0, keepDisplayAwake: true)
        session.isScreenLocked = true
        #expect(fake.current == nil)
    }

    @Test func adjustMovesTheDeadline() {
        let session = Session(assertion: fake)
        session.activate(.minutes(30), now: t0)
        #expect(session.adjust(by: 600, now: t0))
        #expect(session.remaining(now: t0) == .seconds(2400))
        #expect(session.adjust(by: -1200, now: t0.advanced(by: .seconds(100))))
        #expect(session.remaining(now: t0.advanced(by: .seconds(100))) == .seconds(1100))
        #expect(session.duration == .seconds(1100))
    }

    @Test func adjustPastTheEndTurnsOff() {
        let session = Session(assertion: fake)
        var reasons: [EndReason] = []
        session.observeEnd { reasons.append($0.reason) }
        session.activate(.minutes(5), now: t0)
        #expect(session.adjust(by: -300, now: t0))
        #expect(!session.isActive)
        #expect(reasons == [.user])
    }

    @Test func adjustFailsWhenOffOrIndefinite() {
        let session = Session(assertion: fake)
        #expect(!session.adjust(by: 60, now: t0))
        session.activate(.indefinite, now: t0)
        #expect(!session.adjust(by: 60, now: t0))
        #expect(session.endsAt == nil)
    }

    @Test func reactivatingReplacesDurationAndKeepsAssertion() {
        let session = Session(assertion: fake)
        session.activate(.hours(2), now: t0)
        session.activate(.minutes(1), now: t0.advanced(by: .seconds(10)))
        #expect(fake.calls == [.display])
        #expect(session.remaining(now: t0.advanced(by: .seconds(10))) == .seconds(60))
        #expect(session.duration == .minutes(1))
        session.deactivate()
        #expect(session.duration == nil)
    }

    @Test func expiresAndReportsReason() {
        let session = Session(assertion: fake)
        var reasons: [EndReason] = []
        session.observeEnd { reasons.append($0.reason) }
        session.activate(.minutes(1), now: t0)
        session.update(now: t0.advanced(by: .seconds(59)))
        #expect(session.isActive)
        session.update(now: t0.advanced(by: .seconds(60)))
        #expect(!session.isActive)
        #expect(fake.current == nil)
        #expect(reasons == [.expired])
    }

    @Test func toggleAndDeactivate() {
        let session = Session(assertion: fake)
        var reasons: [EndReason] = []
        session.observeEnd { reasons.append($0.reason) }
        session.toggle(.indefinite, now: t0)
        #expect(session.isActive)
        session.toggle(.indefinite, now: t0)
        #expect(!session.isActive)
        session.deactivate()
        #expect(reasons == [.user])
    }

    @Test func displaySettingSwitchesAssertionMidSession() {
        let session = Session(assertion: fake)
        session.activate(.indefinite, now: t0)
        session.keepDisplayAwake = false
        #expect(fake.calls == [.display, .system])
    }

    @Test func lockBehaviorControlsAssertionWhileLocked() {
        let session = Session(assertion: fake)
        session.activate(.minutes(30), now: t0)
        session.isScreenLocked = true
        #expect(fake.current == .display, "keepAwake is the default")

        session.lockBehavior = .allowDisplaySleep
        #expect(fake.current == .system)

        session.lockBehavior = .allowSleep
        #expect(fake.current == nil)
        #expect(session.isActive, "the session keeps running while locked")

        session.isScreenLocked = false
        #expect(fake.current == .display)
    }

    @Test func allowDisplaySleepOnlyAppliesWhileLocked() {
        let session = Session(assertion: fake, lockBehavior: .allowDisplaySleep)
        session.activate(.indefinite, now: t0)
        #expect(fake.current == .display)
        session.isScreenLocked = true
        session.isScreenLocked = false
        #expect(fake.calls == [.display, .system, .display])
    }

    @Test func batteryEndsSessionOnlyOnSwitchAndWhenEnabled() {
        let session = Session(assertion: fake)
        var reasons: [EndReason] = []
        session.observeEnd { reasons.append($0.reason) }

        session.activate(.indefinite, now: t0)
        session.powerSourceChanged(onBattery: true)
        #expect(session.isActive)

        session.powerSourceChanged(onBattery: false)
        session.deactivateOnBattery = true
        session.powerSourceChanged(onBattery: true)
        #expect(!session.isActive)
        #expect(reasons == [.switchedToBattery])

        session.activate(.indefinite, now: t0)
        session.powerSourceChanged(onBattery: true)
        #expect(session.isActive, "staying on battery is not a switch")
    }
}

@MainActor
struct SessionEndObserverTests {
    let t0 = ContinuousClock.now

    @Test func reportsTheEndedSessionOnce() {
        let session = Session(assertion: FakeAssertion(), deactivateOnBattery: true)
        var ended: [EndedSession] = []
        session.observeEnd { ended.append($0) }
        session.activate(.hours(1), now: t0, keepDisplayAwake: false)
        session.activate(.hours(2), now: t0)
        session.powerSourceChanged(onBattery: true)
        session.deactivate()
        #expect(ended == [EndedSession(
            reason: .switchedToBattery, duration: .hours(2), endsAt: t0.advanced(by: .seconds(7200)), keepDisplayAwake: false)])
    }

    @Test func everyObserverIsCalled() {
        let session = Session(assertion: FakeAssertion())
        var a = 0, b = 0
        session.observeEnd { _ in a += 1 }
        session.observeEnd { _ in b += 1 }
        session.activate(.indefinite, now: t0)
        session.deactivate()
        #expect(a == 1 && b == 1)
    }
}

@MainActor
struct SessionHoldObserverTests {
    let t0 = ContinuousClock.now

    @Test func reportsOnlyHoldChanges() {
        let session = Session(assertion: FakeAssertion(), lockBehavior: .allowSleep)
        var holds: [Bool] = []
        session.observeHold { holds.append($0) }
        session.activate(.indefinite, now: t0)
        session.keepDisplayAwake.toggle()
        session.isScreenLocked = true
        session.isScreenLocked = false
        session.deactivate()
        #expect(holds == [true, false, true, false], "a kind change (display to system) is not a hold change")
        #expect(!session.isHoldingAssertion)
    }
}
