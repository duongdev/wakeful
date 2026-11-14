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

    /// Parses `wakeful://activate?hours=1.5&minutes=10`, `wakeful://deactivate`, `wakeful://toggle?minutes=30`,
    /// `wakeful://settings`.
    /// Returns nil for an unknown action or an invalid duration.
    public init?(url: URL) {
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
            guard case .valid(let duration) = Self.parseDuration(items) else { return nil }
            self = action == "activate" ? .activate(duration) : .toggle(duration)
        default:
            return nil
        }
    }

    /// Longest accepted duration. Also keeps huge inputs (e.g. `hours=1e308`) from overflowing to infinity,
    /// which would crash when converted to `Duration`.
    public static let maxSeconds: Double = 999 * 3600

    private enum Parsed { case valid(SessionDuration?), invalid }

    private static func parseDuration(_ items: [URLQueryItem]) -> Parsed {
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
}
