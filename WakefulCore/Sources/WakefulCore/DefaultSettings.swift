/// How the menu bar icon looks while Wakeful is on. Off always uses the plain icon.
public enum ActiveIconStyle: String, CaseIterable, Sendable {
    case standard, green, blue, greenDot, blueDot
}

/// First-launch defaults, in one place so they are easy to change after feedback.
/// How hot the Mac may get before lid-closed mode lets it sleep. Matches `ProcessInfo.ThermalState`.
public enum HeatLimit: String, CaseIterable, Sendable {
    case serious, critical, never
}

public enum DefaultSettings {
    public static let keepDisplayAwake = true
    public static let defaultDuration = SessionDuration.indefinite
    public static let toggleOnLeftClick = false
    public static let activateAtLaunch = false
    public static let deactivateOnBattery = false
    public static let resumeOnPlugIn = false
    public static let lidClosedMode = false
    public static let lidClosedOnBattery = false
    public static let lidClosedMinBattery = 20
    public static let lidClosedHeatLimit = HeatLimit.serious
    public static let lockBehavior = LockBehavior.keepAwake
    public static let dimIconWhenInactive = false
    public static let notifyWhenSessionEnds = true
    public static let showTimeLeftInMenuBar = false
    public static let activeIconStyle = ActiveIconStyle.standard

    /// For `UserDefaults.register(defaults:)`, so reads need no fallback.
    public static var registration: [String: Any] { [
        SettingsKey.keepDisplayAwake: keepDisplayAwake,
        SettingsKey.defaultDuration: defaultDuration.storedValue,
        SettingsKey.toggleOnLeftClick: toggleOnLeftClick,
        SettingsKey.activateAtLaunch: activateAtLaunch,
        SettingsKey.deactivateOnBattery: deactivateOnBattery,
        SettingsKey.resumeOnPlugIn: resumeOnPlugIn,
        SettingsKey.lidClosedMode: lidClosedMode,
        SettingsKey.lidClosedOnBattery: lidClosedOnBattery,
        SettingsKey.lidClosedMinBattery: lidClosedMinBattery,
        SettingsKey.lidClosedHeatLimit: lidClosedHeatLimit.rawValue,
        SettingsKey.lockBehavior: lockBehavior.rawValue,
        SettingsKey.dimIconWhenInactive: dimIconWhenInactive,
        SettingsKey.notifyWhenSessionEnds: notifyWhenSessionEnds,
        SettingsKey.showTimeLeftInMenuBar: showTimeLeftInMenuBar,
        SettingsKey.activeIconStyle: activeIconStyle.rawValue,
    ] }
}

/// `UserDefaults` keys for the settings above.
public enum SettingsKey {
    public static let keepDisplayAwake = "keepDisplayAwake"
    public static let defaultDuration = "defaultDuration"
    public static let toggleOnLeftClick = "toggleOnLeftClick"
    public static let activateAtLaunch = "activateAtLaunch"
    public static let deactivateOnBattery = "deactivateOnBattery"
    /// Pro. The free app shows this setting locked.
    public static let resumeOnPlugIn = "resumeOnPlugIn"
    /// Pro. The free app shows this setting locked.
    public static let lidClosedMode = "lidClosedMode"
    public static let lidClosedOnBattery = "lidClosedOnBattery"
    public static let lidClosedMinBattery = "lidClosedMinBattery"
    public static let lidClosedHeatLimit = "lidClosedHeatLimit"
    public static let lockBehavior = "lockBehavior"
    public static let dimIconWhenInactive = "dimIconWhenInactive"
    public static let notifyWhenSessionEnds = "notifyWhenSessionEnds"
    public static let showTimeLeftInMenuBar = "showTimeLeftInMenuBar"
    public static let activeIconStyle = "activeIconStyle"
}

/// `UserDefaults` keys the app writes so the command-line tool can read the state.
public enum StateKey {
    public static let isActive = "state.isActive"
    /// Wall-clock end time. Missing while off or indefinite.
    public static let endsAt = "state.endsAt"
    /// When the app last wrote the state, so the tool can tell its command was handled.
    public static let updatedAt = "state.updatedAt"
}
