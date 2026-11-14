/// First-launch defaults, in one place so they are easy to change after feedback.
public enum DefaultSettings {
    public static let keepDisplayAwake = true
    public static let defaultDuration = SessionDuration.indefinite
    public static let toggleOnLeftClick = false
    public static let activateAtLaunch = false
    public static let deactivateOnBattery = false
    public static let lockBehavior = LockBehavior.keepAwake
    public static let dimIconWhenInactive = false
    public static let notifyWhenSessionEnds = true
    public static let showTimeLeftInMenuBar = false

    /// For `UserDefaults.register(defaults:)`, so reads need no fallback.
    public static var registration: [String: Any] { [
        SettingsKey.keepDisplayAwake: keepDisplayAwake,
        SettingsKey.defaultDuration: defaultDuration.storedValue,
        SettingsKey.toggleOnLeftClick: toggleOnLeftClick,
        SettingsKey.activateAtLaunch: activateAtLaunch,
        SettingsKey.deactivateOnBattery: deactivateOnBattery,
        SettingsKey.lockBehavior: lockBehavior.rawValue,
        SettingsKey.dimIconWhenInactive: dimIconWhenInactive,
        SettingsKey.notifyWhenSessionEnds: notifyWhenSessionEnds,
        SettingsKey.showTimeLeftInMenuBar: showTimeLeftInMenuBar,
    ] }
}

/// `UserDefaults` keys for the settings above.
public enum SettingsKey {
    public static let keepDisplayAwake = "keepDisplayAwake"
    public static let defaultDuration = "defaultDuration"
    public static let toggleOnLeftClick = "toggleOnLeftClick"
    public static let activateAtLaunch = "activateAtLaunch"
    public static let deactivateOnBattery = "deactivateOnBattery"
    public static let lockBehavior = "lockBehavior"
    public static let dimIconWhenInactive = "dimIconWhenInactive"
    public static let notifyWhenSessionEnds = "notifyWhenSessionEnds"
    public static let showTimeLeftInMenuBar = "showTimeLeftInMenuBar"
}
