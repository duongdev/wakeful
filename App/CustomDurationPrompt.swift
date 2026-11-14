import AppKit
import WakefulCore

/// Asks for hours and minutes. Returns nil if the user cancels or enters zero.
@MainActor
enum CustomDurationPrompt {
    static func run() -> SessionDuration? {
        let alert = NSAlert()
        alert.messageText = String(localized: "Keep Awake For")
        alert.addButton(withTitle: String(localized: "Start"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        let hours = field(placeholder: String(localized: "Hours"))
        let minutes = field(placeholder: String(localized: "Minutes"))
        let stack = NSStackView(views: [hours, NSTextField(labelWithString: "h"), minutes, NSTextField(labelWithString: "min")])
        stack.frame = NSRect(x: 0, y: 0, width: 220, height: 24)
        alert.accessoryView = stack
        alert.window.initialFirstResponder = hours

        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let total = Double(hours.integerValue) * 3600 + Double(minutes.integerValue) * 60
        return total > 0 ? .seconds(total) : nil
    }

    /// Asks for a time of day. Returns the time until then; a past time means tomorrow. Nil if the user cancels.
    static func runUntil() -> SessionDuration? {
        let alert = NSAlert()
        alert.messageText = String(localized: "Keep Awake Until")
        alert.informativeText = String(localized: "A time that has passed today means tomorrow.")
        alert.addButton(withTitle: String(localized: "Start"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        let picker = NSDatePicker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = .hourMinute
        let calendar = Calendar.current
        let nextHour = calendar.nextDate(after: .now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime)
        picker.dateValue = nextHour ?? .now
        picker.sizeToFit()
        alert.accessoryView = picker
        alert.window.initialFirstResponder = picker

        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let time = calendar.dateComponents([.hour, .minute], from: picker.dateValue)
        return SessionDuration.until(hour: time.hour ?? 0, minute: time.minute ?? 0, now: .now, calendar: calendar)
    }

    private static func field(placeholder: String) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.formatter = {
            let f = NumberFormatter()
            f.allowsFloats = false
            f.minimum = 0
            f.maximum = 999
            return f
        }()
        field.widthAnchor.constraint(equalToConstant: 60).isActive = true
        return field
    }
}
