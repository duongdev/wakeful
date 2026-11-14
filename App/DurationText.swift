import Foundation
import WakefulCore

enum DurationText {
    /// Menu label, Title Case in English ("10 Minutes", "1 Hour 30 Minutes").
    static func label(_ duration: SessionDuration) -> String {
        guard let seconds = duration.timeInterval else { return String(localized: "Indefinitely") }
        return titleCase(format(seconds, style: .full))
    }

    /// "Ends at 3:45 PM (in 25 minutes)".
    static func endsLabel(_ remaining: Duration) -> String {
        let seconds = max(0, Double(remaining.components.seconds))
        let end = Date().addingTimeInterval(seconds).formatted(date: .omitted, time: .shortened)
        let left = format(roundedUpToMinute(seconds), style: .full)
        return String(localized: "Ends at \(end) (in \(left))")
    }

    /// Short countdown for the menu bar: "25m", "1h 5m".
    static func short(_ remaining: Duration) -> String {
        format(roundedUpToMinute(max(0, Double(remaining.components.seconds))), style: .abbreviated)
    }

    private static func roundedUpToMinute(_ seconds: Double) -> Double {
        max(60, (seconds / 60).rounded(.up) * 60)
    }

    private static func format(_ seconds: TimeInterval, style: DateComponentsFormatter.UnitsStyle) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = style
        return formatter.string(from: seconds) ?? ""
    }

    /// macOS menus use Title Case in English only; other languages keep their own rules.
    private static func titleCase(_ text: String) -> String {
        Locale.current.language.languageCode == .english ? text.localizedCapitalized : text
    }
}
