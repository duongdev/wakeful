import AppIntents
import WakefulCore

enum WakefulIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notRunning
    case notTimed
    case durationAndEndTime

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notRunning: "Wakeful is not running."
        case .notTimed: "Wakeful is off or on with no end time, so there is no time to change."
        case .durationAndEndTime: "Give a duration or an end time, not both."
        }
    }
}

@MainActor
private func app() throws -> AppDelegate {
    guard let app = AppDelegate.shared else { throw WakefulIntentError.notRunning }
    return app
}

private func sessionDuration(_ duration: Measurement<UnitDuration>?, until: Date?) throws -> SessionDuration? {
    switch (duration, until) {
    case (.some, .some):
        throw WakefulIntentError.durationAndEndTime
    case (let duration?, nil):
        let seconds = duration.converted(to: .seconds).value
        return seconds > 0 ? .seconds(min(seconds, Command.maxSeconds)) : .indefinite
    case (nil, let until?):
        let time = Calendar.current.dateComponents([.hour, .minute], from: until)
        return SessionDuration.until(hour: time.hour ?? 0, minute: time.minute ?? 0, now: .now)
    case (nil, nil):
        return nil
    }
}

enum DisplaySleepChoice: String, AppEnum {
    case useSetting, keepAwake, allowSleep

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Display"
    static let caseDisplayRepresentations: [DisplaySleepChoice: DisplayRepresentation] = [
        .useSetting: "Use Wakeful Setting",
        .keepAwake: "Keep Display Awake",
        .allowSleep: "Let Display Sleep",
    ]

    /// The per-session override, or nil for the setting.
    var keepDisplayAwake: Bool? {
        switch self {
        case .useSetting: nil
        case .keepAwake: true
        case .allowSleep: false
        }
    }
}

struct TurnOnIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn On Wakeful"
    static let description = IntentDescription(
        "Keeps your Mac awake. With no duration or end time, Wakeful uses your default duration. A duration of 0 means until you turn it off.")

    @Parameter(title: "Duration", defaultUnit: .minutes, supportsNegativeNumbers: false)
    var duration: Measurement<UnitDuration>?

    @Parameter(title: "End Time", description: "A past time today means tomorrow.", kind: .time)
    var until: Date?

    @Parameter(title: "Display", description: "For this session only.", default: .useSetting)
    var display: DisplaySleepChoice

    @MainActor
    func perform() async throws -> some IntentResult {
        try app().activate(sessionDuration(duration, until: until), keepDisplayAwake: display.keepDisplayAwake)
        return .result()
    }
}

struct TurnOffIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn Off Wakeful"
    static let description = IntentDescription("Lets your Mac sleep normally again.")

    @MainActor
    func perform() async throws -> some IntentResult {
        try app().deactivate()
        return .result()
    }
}

struct ToggleIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Wakeful"
    static let description = IntentDescription(
        "Turns Wakeful on if it is off, or off if it is on. With no duration, Wakeful uses your default duration.")

    @Parameter(title: "Duration", defaultUnit: .minutes, supportsNegativeNumbers: false)
    var duration: Measurement<UnitDuration>?

    @Parameter(title: "Display", description: "For this session only, when it turns on.", default: .useSetting)
    var display: DisplaySleepChoice

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let app = try app()
        app.toggle(try sessionDuration(duration, until: nil), keepDisplayAwake: display.keepDisplayAwake)
        return .result(value: app.isActive)
    }
}

struct GetStateIntent: AppIntent {
    static let title: LocalizedStringResource = "Is Wakeful On"
    static let description = IntentDescription("Returns true while Wakeful keeps your Mac awake.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: try app().isActive)
    }
}

struct GetTimeLeftIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Wakeful Time Left"
    static let description = IntentDescription(
        "Returns the time left in the session. Returns nothing when Wakeful is off or on with no end time.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Measurement<UnitDuration>?> {
        let left = try app().remaining.map { Double($0.components.seconds) }
        return .result(value: left.map { Measurement(value: $0, unit: UnitDuration.seconds) })
    }
}

struct AdjustTimeIntent: AppIntent {
    static let title: LocalizedStringResource = "Change Wakeful Time"
    static let description = IntentDescription(
        "Adds time to the running session, or removes it with a negative value. Fails when Wakeful is off or on with no end time.")

    @Parameter(title: "Time", defaultUnit: .minutes)
    var amount: Measurement<UnitDuration>

    @MainActor
    func perform() async throws -> some IntentResult {
        guard try app().adjust(by: amount.converted(to: .seconds).value) else { throw WakefulIntentError.notTimed }
        return .result()
    }
}

struct WakefulShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TurnOnIntent(),
            phrases: ["Turn on \(.applicationName)", "Keep my Mac awake with \(.applicationName)"],
            shortTitle: "Turn On",
            systemImageName: "cup.and.saucer.fill")
        AppShortcut(
            intent: TurnOffIntent(),
            phrases: ["Turn off \(.applicationName)"],
            shortTitle: "Turn Off",
            systemImageName: "cup.and.saucer")
        AppShortcut(
            intent: ToggleIntent(),
            phrases: ["Toggle \(.applicationName)"],
            shortTitle: "Toggle",
            systemImageName: "arrow.left.arrow.right")
    }
}
