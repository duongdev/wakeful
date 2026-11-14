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

    var body: some View {
        Form {
            Section("Session") {
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
                Toggle("Turn off when I unplug the charger", isOn: $deactivateOnBattery)
                Toggle("Notify me when a session ends", isOn: $notifyWhenSessionEnds)
            }
            Section("General") {
                Picker("Language", selection: $language) {
                    Text("System Default").tag("")
                    ForEach(AppLanguage.available, id: \.self) { Text(AppLanguage.name($0)).tag($0) }
                }
                .onChange(of: language) { _, code in
                    AppLanguage.set(code)
                    askToRestart = true
                }
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                KeyboardShortcuts.Recorder("Keyboard shortcut to turn on or off", name: .toggleWakeful)
                Toggle("Turn on when Wakeful starts", isOn: $activateAtLaunch)
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
                Toggle("Check for updates automatically", isOn: $automaticUpdates)
            }
            Section("Advanced") {
                HStack {
                    Button("Show Logs") { WindowPresenter.shared.showLogs() }
                    Button("Copy Logs") { LogsView.copyToClipboard() }
                    Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([Log.shared.fileURL]) }
                }
            }
            Section {
                Text("Version \(Bundle.main.versionString)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .alert("Restart Wakeful to use the new language.", isPresented: $askToRestart) {
            Button("Restart Now") { AppLanguage.relaunch() }
            Button("Later", role: .cancel) {}
        }
        .frame(width: 440)
        .fixedSize()
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
