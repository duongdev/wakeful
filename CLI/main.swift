import AppKit
import WakefulCore

/// The Debug tool talks to the Debug app, so it never changes an installed copy.
enum Target {
    #if DEBUG
    static let bundleID = "dev.duongdev.Wakeful.debug"
    static let scheme = "wakeful-dev"
    #else
    static let bundleID = "dev.duongdev.Wakeful"
    static let scheme = "wakeful"
    #endif
}

let usage = """
    Usage: wakeful <command>

      on [DURATION]       Keep the Mac awake. With no duration, uses your default.
      on until HH:MM      Keep the Mac awake until a time (24-hour). A past time means tomorrow.
      off                 Let the Mac sleep normally.
      toggle [DURATION]   Turn on if off, or off if on.
      status              Show whether Wakeful is on and the time left.

    DURATION: 30m, 2h, 1.5h, 1h30m, 90s, a number of minutes, or forever.
    """

struct State {
    var isActive: Bool
    var endsAt: Date?
    var updatedAt: Date?
}

func isAppRunning() -> Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: Target.bundleID).isEmpty
}

func readState() -> State {
    CFPreferencesAppSynchronize(Target.bundleID as CFString)
    let active = CFPreferencesCopyAppValue(StateKey.isActive as CFString, Target.bundleID as CFString) as? Bool ?? false
    let endsAt = CFPreferencesCopyAppValue(StateKey.endsAt as CFString, Target.bundleID as CFString) as? Date
    let updatedAt = CFPreferencesCopyAppValue(StateKey.updatedAt as CFString, Target.bundleID as CFString) as? Date
    return State(isActive: active, endsAt: active ? endsAt : nil, updatedAt: updatedAt)
}

func describe(_ state: State) -> String {
    guard state.isActive else { return "Off" }
    guard let endsAt = state.endsAt else { return "On, until you turn it off" }
    let minutes = Int((endsAt.timeIntervalSinceNow / 60).rounded(.up))
    let left = switch (minutes / 60, minutes % 60) {
    case (0, let m): "\(max(m, 0))m"
    case (let h, 0): "\(h)h"
    case (let h, let m): "\(h)h \(m)m"
    }
    return "On, \(left) left (until \(endsAt.formatted(date: .omitted, time: .shortened)))"
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("wakeful: \(message)\n".utf8))
    exit(1)
}

/// Sends the command through the URL scheme (which also launches the app), then waits until the app
/// has written a new state that matches.
func send(_ command: Command, until done: (State) -> Bool) -> Never {
    let sentAt = Date.now
    let open = Process()
    open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    open.arguments = ["-g", command.url(scheme: Target.scheme).absoluteString]
    do { try open.run() } catch { fail("could not open Wakeful: \(error.localizedDescription)") }
    open.waitUntilExit()
    guard open.terminationStatus == 0 else { fail("could not open Wakeful. Is it installed?") }
    let deadline = Date.now.addingTimeInterval(10)
    while Date.now < deadline {
        let state = readState()
        if let updatedAt = state.updatedAt, updatedAt >= sentAt, done(state) {
            print(describe(state))
            exit(0)
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
    fail("Wakeful did not respond")
}

func parseDuration(_ args: ArraySlice<String>) -> SessionDuration? {
    if args.isEmpty { return nil }
    if args.first == "until" {
        guard args.count == 2, let (hour, minute) = Command.parseClockTime(args.last!),
              let duration = SessionDuration.until(hour: hour, minute: minute, now: .now)
        else { fail("expected a time like 18:00 after 'until'") }
        return duration
    }
    guard let duration = SessionDuration(cli: args.joined()) else { fail("invalid duration '\(args.joined(separator: " "))'") }
    return duration
}

let args = CommandLine.arguments.dropFirst()
let before = isAppRunning() ? readState() : State(isActive: false)

switch args.first {
case "on":
    let duration = parseDuration(args.dropFirst())
    send(.activate(duration)) { $0.isActive }
case "off":
    guard isAppRunning(), before.isActive else { print(describe(State(isActive: false))); exit(0) }
    send(.deactivate) { !$0.isActive }
case "toggle":
    let duration = parseDuration(args.dropFirst())
    send(.toggle(duration)) { $0.isActive != before.isActive }
case "status":
    guard args.count == 1 else { fail("'status' takes no arguments") }
    print(isAppRunning() ? describe(before) : "Off (Wakeful is not running)")
case "help", "-h", "--help", nil:
    print(usage)
default:
    fail("unknown command '\(args.first!)'. Run 'wakeful help'.")
}
