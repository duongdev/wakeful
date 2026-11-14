import Foundation
import Testing
@testable import WakefulCore

struct CommandTests {
    private func parse(_ s: String) -> Command? { Command(url: URL(string: s)!) }

    @Test func parsesActions() {
        #expect(parse("wakeful://activate") == .activate(nil))
        #expect(parse("wakeful://deactivate") == .deactivate)
        #expect(parse("wakeful://toggle") == .toggle(nil))
        #expect(parse("wakeful://settings") == .openSettings)
        #expect(parse("wakeful:activate") == .activate(nil))
        #expect(parse("WAKEFUL://Activate") == .activate(nil))
        #expect(parse("wakeful-dev://activate") == .activate(nil))
        #expect(parse("other://activate") == nil)
    }

    @Test func parsesDurations() {
        #expect(parse("wakeful://activate?minutes=30") == .activate(.seconds(1800)))
        #expect(parse("wakeful://activate?hours=1.5") == .activate(.seconds(5400)))
        #expect(parse("wakeful://toggle?hours=1&minutes=10") == .toggle(.seconds(4200)))
    }

    @Test func rejectsInvalidInput() {
        #expect(parse("wakeful://sleep") == nil)
        #expect(parse("other://activate") == nil)
        #expect(parse("wakeful://activate?minutes=abc") == nil)
        #expect(parse("wakeful://activate?minutes=-5") == nil)
        #expect(parse("wakeful://activate?minutes=0") == nil)
        #expect(parse("wakeful://activate?hours=inf") == nil)
        #expect(parse("wakeful://activate?hours=1e308") == nil, "overflows to infinity")
        #expect(parse("wakeful://activate?hours=1000") == nil, "over the 999 hour cap")
        #expect(parse("wakeful://activate?hours=999") == .activate(.hours(999)))
    }

    @Test func parsesUntilTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Ho_Chi_Minh"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 9, minute: 30)))
        let parse = { (s: String) in Command(url: URL(string: s)!, now: now, calendar: calendar) }
        #expect(parse("wakeful://activate?until=18:00") == .activate(.hours(8.5)))
        #expect(parse("wakeful://toggle?until=9:45") == .toggle(.minutes(15)))
        #expect(parse("wakeful://activate?until=09:00") == .activate(.hours(23.5)), "a past time means tomorrow")
        #expect(parse("wakeful://activate?until=09:30") == .activate(.hours(24)), "now means tomorrow")
        #expect(parse("wakeful://activate?until=24:00") == nil)
        #expect(parse("wakeful://activate?until=18") == nil)
        #expect(parse("wakeful://activate?until=6pm") == nil)
        #expect(parse("wakeful://activate?until=18:00&hours=1") == nil, "until and a duration together")
    }

    @Test func untilHandlesDaylightSavingDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        // 2026-03-08: clocks jump from 02:00 to 03:00, so 01:00 to 04:00 is 2 hours.
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 1)))
        #expect(SessionDuration.until(hour: 4, minute: 0, now: now, calendar: calendar) == .hours(2))
    }

    @Test func parsesIndefinitely() {
        #expect(parse("wakeful://activate?indefinitely") == .activate(.indefinite))
        #expect(parse("wakeful://toggle?indefinitely") == .toggle(.indefinite))
        #expect(parse("wakeful://activate?indefinitely&minutes=5") == nil)
    }

    @Test func urlRoundTrips() {
        let commands: [Command] = [
            .activate(nil), .activate(.indefinite), .activate(.minutes(30)), .activate(.seconds(5400)),
            .toggle(nil), .toggle(.hours(2)), .deactivate, .openSettings,
        ]
        for command in commands {
            #expect(Command(url: command.url(scheme: "wakeful")) == command, "\(command)")
        }
        #expect(Command.deactivate.url(scheme: "wakeful-dev").absoluteString == "wakeful-dev://deactivate")
    }

    @Test func parsesCLIDurations() {
        #expect(SessionDuration(cli: "30m") == .minutes(30))
        #expect(SessionDuration(cli: "45") == .minutes(45), "a plain number is minutes")
        #expect(SessionDuration(cli: "2h") == .hours(2))
        #expect(SessionDuration(cli: "1.5h") == .hours(1.5))
        #expect(SessionDuration(cli: "1h30m") == .minutes(90))
        #expect(SessionDuration(cli: "90s") == .seconds(90))
        #expect(SessionDuration(cli: "1H 30M") == .minutes(90))
        #expect(SessionDuration(cli: "forever") == .indefinite)
        #expect(SessionDuration(cli: "indefinitely") == .indefinite)
        for bad in ["", "0", "0m", "-5m", "abc", "1x", "h", "1h1h", "30m1h", "1000h", "1e308h", "inf"] {
            #expect(SessionDuration(cli: bad) == nil, "\(bad)")
        }
    }

    @Test func storedDurationRoundTrips() {
        #expect(SessionDuration(storedValue: 0) == .indefinite)
        #expect(SessionDuration(storedValue: SessionDuration.hours(2).storedValue) == .hours(2))
    }
}
