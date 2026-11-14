import Foundation

/// How long a session lasts.
public enum SessionDuration: Hashable, Codable, Sendable {
    case indefinite
    case seconds(TimeInterval)

    public static func minutes(_ value: Double) -> SessionDuration { .seconds(value * 60) }
    public static func hours(_ value: Double) -> SessionDuration { .seconds(value * 3600) }

    public static let presets: [SessionDuration] = [
        .indefinite, .minutes(10), .minutes(30), .hours(1), .hours(2), .hours(4), .hours(8), .hours(12),
    ]

    public var timeInterval: TimeInterval? {
        if case .seconds(let s) = self { s } else { nil }
    }

    /// Plain number for `UserDefaults`: seconds, or 0 for indefinite.
    public var storedValue: Double { timeInterval ?? 0 }

    public init(storedValue: Double) {
        self = storedValue > 0 ? .seconds(storedValue) : .indefinite
    }
}
