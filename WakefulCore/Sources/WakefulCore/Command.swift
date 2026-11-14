import Foundation

/// A control action from the URL scheme (and later the CLI and Shortcuts).
/// A `nil` duration means "use the default duration".
public enum Command: Equatable, Sendable {
    case activate(SessionDuration?)
    case deactivate
    case toggle(SessionDuration?)
    case openSettings

    /// `wakeful-dev` is the Debug build's scheme, so it does not take links meant for the installed app.
    public static let urlSchemes: Set = ["wakeful", "wakeful-dev"]

    /// Parses `wakeful://activate?hours=1.5&minutes=10`, `wakeful://activate?until=18:00`,
    /// `wakeful://activate?indefinitely`, `wakeful://deactivate`, `wakeful://toggle?minutes=30`, `wakeful://settings`.
    /// `until` is a 24-hour wall-clock time; a past time means tomorrow.
    /// Returns nil for an unknown action or an invalid duration.
    public init?(url: URL, now: Date = .now, calendar: Calendar = .current) {
        guard let scheme = url.scheme?.lowercased(), Self.urlSchemes.contains(scheme),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        // Accept both `wakeful://activate` (host) and `wakeful:activate` (path).
        let action = (components.host ?? components.path).lowercased()
        let items = components.queryItems ?? []

        switch action {
        case "deactivate":
            self = .deactivate
        case "settings":
            self = .openSettings
        case "activate", "toggle":
            guard case .valid(let duration) = Self.parseDuration(items, now: now, calendar: calendar) else { return nil }
            self = action == "activate" ? .activate(duration) : .toggle(duration)
        default:
            return nil
        }
    }

    /// Longest accepted duration. Also keeps huge inputs (e.g. `hours=1e308`) from overflowing to infinity,
    /// which would crash when converted to `Duration`.
    public static let maxSeconds: Double = 999 * 3600

    private enum Parsed { case valid(SessionDuration?), invalid }

    private static func parseDuration(_ items: [URLQueryItem], now: Date, calendar: Calendar) -> Parsed {
        let durationNames: Set = ["hours", "minutes", "until", "indefinitely"]
        if items.contains(where: { $0.name == "indefinitely" }) {
            return items.filter({ durationNames.contains($0.name) }).count == 1 ? .valid(.indefinite) : .invalid
        }
        if let until = items.first(where: { $0.name == "until" })?.value {
            guard !items.contains(where: { $0.name == "hours" || $0.name == "minutes" }),
                  let (hour, minute) = parseClockTime(until),
                  let duration = SessionDuration.until(hour: hour, minute: minute, now: now, calendar: calendar)
            else { return .invalid }
            return .valid(duration)
        }
        var seconds = 0.0
        var given = false
        for (name, factor) in [("hours", 3600.0), ("minutes", 60.0)] {
            guard let raw = items.first(where: { $0.name == name })?.value else { continue }
            guard let value = Double(raw), value.isFinite, value >= 0 else { return .invalid }
            seconds += value * factor
            given = true
        }
        if !given { return .valid(nil) }
        return seconds > 0 && seconds <= maxSeconds ? .valid(.seconds(seconds)) : .invalid
    }

    /// The URL that `init?(url:)` parses back to this command.
    public func url(scheme: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        let duration: SessionDuration?
        switch self {
        case .activate(let d): components.host = "activate"; duration = d
        case .toggle(let d): components.host = "toggle"; duration = d
        case .deactivate: components.host = "deactivate"; duration = nil
        case .openSettings: components.host = "settings"; duration = nil
        }
        switch duration {
        case nil: break
        case .indefinite: components.queryItems = [URLQueryItem(name: "indefinitely", value: nil)]
        case .seconds(let s): components.queryItems = [URLQueryItem(name: "minutes", value: String(s / 60))]
        }
        return components.url!
    }

    /// `H:mm` or `HH:mm`, 24-hour.
    public static func parseClockTime(_ text: String) -> (Int, Int)? {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, (1...2).contains(parts[0].count), parts[1].count == 2,
              parts.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute)
        else { return nil }
        return (hour, minute)
    }
}
