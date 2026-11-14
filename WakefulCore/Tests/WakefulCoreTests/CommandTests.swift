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
    }

    @Test func storedDurationRoundTrips() {
        #expect(SessionDuration(storedValue: 0) == .indefinite)
        #expect(SessionDuration(storedValue: SessionDuration.hours(2).storedValue) == .hours(2))
    }
}
