import KeyboardShortcuts
import ServiceManagement
import SwiftUI
import WakefulCore

struct SettingsView: View {
    @AppStorage(SettingsKey.keepDisplayAwake) private var keepDisplayAwake = DefaultSettings.keepDisplayAwake
    @AppStorage(SettingsKey.defaultDuration) private var defaultDuration = DefaultSettings.defaultDuration.storedValue
    @AppStorage(SettingsKey.toggleOnLeftClick) private var toggleOnLeftClick = DefaultSettings.toggleOnLeftClick
    @AppStorage(SettingsKey.activateAtLaunch) private var activateAtLaunch = DefaultSettings.activateAtLaunch
    @AppStorage(SettingsKey.deactivateOnBattery) private var deactivateOnBattery = DefaultSettings.deactivateOnBattery
    @AppStorage(SettingsKey.resumeOnPlugIn) private var resumeOnPlugIn = DefaultSettings.resumeOnPlugIn
    @AppStorage(SettingsKey.lidClosedMode) private var lidClosedMode = DefaultSettings.lidClosedMode
    @AppStorage(SettingsKey.lidClosedOnBattery) private var lidClosedOnBattery = DefaultSettings.lidClosedOnBattery
    @AppStorage(SettingsKey.lidClosedMinBattery) private var lidClosedMinBattery = DefaultSettings.lidClosedMinBattery
    @AppStorage(SettingsKey.lidClosedHeatLimit) private var lidClosedHeatLimit = DefaultSettings.lidClosedHeatLimit
    @AppStorage(SettingsKey.lockBehavior) private var lockBehavior = DefaultSettings.lockBehavior
    @AppStorage(SettingsKey.dimIconWhenInactive) private var dimIconWhenInactive = DefaultSettings.dimIconWhenInactive
    @AppStorage(SettingsKey.notifyWhenSessionEnds) private var notifyWhenSessionEnds = DefaultSettings.notifyWhenSessionEnds
    @AppStorage(SettingsKey.activeIconStyle) private var activeIconStyle = DefaultSettings.activeIconStyle
    @AppStorage(SettingsKey.showTimeLeftInMenuBar) private var showTimeLeftInMenuBar = DefaultSettings.showTimeLeftInMenuBar
    // Sparkle reads this key from user defaults; Info.plist sets the default.
    @AppStorage("SUEnableAutomaticChecks") private var automaticUpdates = true
    @State private var language = AppLanguage.current
    @State private var askToRestart = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var unlocked = AppDelegate.shared?.unlockedFeatures ?? []

    var body: some View {
        Form {
            Section("Keep Awake") {
                Picker("Default duration", selection: $defaultDuration) {
                    ForEach(SessionDuration.presets, id: \.self) { preset in
                        Text(DurationText.label(preset)).tag(preset.storedValue)
                    }
                }
                Toggle("Keep the display awake", isOn: $keepDisplayAwake)
                Picker("When the screen is locked", selection: $lockBehavior) {
                    Text("Keep everything awake").tag(LockBehavior.keepAwake)
                    Text("Let the display sleep").tag(LockBehavior.allowDisplaySleep)
                    Text("Let the Mac sleep").tag(LockBehavior.allowSleep)
                }
                Toggle("Notify me when a session ends", isOn: $notifyWhenSessionEnds)
            }
            Section("Power") {
                Toggle("Turn off when I unplug the charger", isOn: $deactivateOnBattery)
                proToggle("Turn on again when I plug the charger in", .resumeOnPlugIn, isOn: $resumeOnPlugIn)
                    .disabled(!deactivateOnBattery)
                if Hardware.hasLid {
                    proToggle("Keep the Mac awake with the lid closed", .lidClosedMode, isOn: $lidClosedMode)
                    // Locked, the options show dimmed so the free app shows what Pro adds.
                    let locked = !unlocked.contains(.lidClosedMode)
                    if lidClosedMode || locked {
                        Group {
                            Toggle("Also on battery", isOn: $lidClosedOnBattery)
                            if lidClosedOnBattery || locked {
                                Picker("Turn off below", selection: $lidClosedMinBattery) {
                                    ForEach([10, 20, 30, 50], id: \.self) { Text("\($0)%").tag($0) }
                                }
                            }
                            Picker("Turn off when the Mac gets", selection: $lidClosedHeatLimit) {
                                Text("Hot").tag(HeatLimit.serious)
                                Text("Very hot").tag(HeatLimit.critical)
                                Text("Never").tag(HeatLimit.never)
                            }
                        }
                        .disabled(locked)
                    }
                }
            }
            Section("Menu Bar Icon") {
                Toggle("Left-click the icon to turn on or off", isOn: $toggleOnLeftClick)
                if toggleOnLeftClick {
                    Text("Right-click the icon to open the menu.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Picker("Icon when on", selection: $activeIconStyle) {
                    Text("Standard").tag(ActiveIconStyle.standard)
                    Text("Green").tag(ActiveIconStyle.green)
                    Text("Blue").tag(ActiveIconStyle.blue)
                    Text("Green Dot").tag(ActiveIconStyle.greenDot)
                    Text("Blue Dot").tag(ActiveIconStyle.blueDot)
                }
                Toggle("Dim the icon when off", isOn: $dimIconWhenInactive)
                Toggle("Show time left next to the icon", isOn: $showTimeLeftInMenuBar)
            }
            Section("General") {
                Toggle("Turn on when Wakeful starts", isOn: $activateAtLaunch)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                KeyboardShortcuts.Recorder("Keyboard shortcut to turn on or off", name: .toggleWakeful)
                Picker("Language", selection: $language) {
                    Text("System Default").tag("")
                    ForEach(AppLanguage.available, id: \.self) { Text(AppLanguage.name($0)).tag($0) }
                }
                .onChange(of: language) { _, code in
                    AppLanguage.set(code)
                    askToRestart = true
                }
                Toggle("Check for updates automatically", isOn: $automaticUpdates)
            }
            Section {
                LabeledContent("Logs") {
                    Button("Show Logs") { WindowPresenter.shared.showLogs() }
                }
            } footer: {
                Text("Version \(Bundle.main.versionString)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        // What is unlocked can change while the window is open.
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            unlocked = AppDelegate.shared?.unlockedFeatures ?? []
        }
        .alert("Restart Wakeful to use the new language.", isPresented: $askToRestart) {
            Button("Restart Now") { AppLanguage.relaunch() }
            Button("Later", role: .cancel) {}
        }
        // A fixed height that scrolls: the full form is taller than a 13-inch screen.
        .frame(width: 440, height: 600)
    }

    /// A Pro setting. Locked, it shows off and says it is a Pro feature.
    @ViewBuilder
    private func proToggle(_ title: LocalizedStringKey, _ feature: ProFeature, isOn: Binding<Bool>) -> some View {
        if unlocked.contains(feature) {
            Toggle(title, isOn: isOn)
        } else {
            Toggle(isOn: .constant(false)) {
                Text(title)
                Text("Pro feature")
            }
            .disabled(true)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            Log.shared.error("Launch at login: \(error.localizedDescription)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
