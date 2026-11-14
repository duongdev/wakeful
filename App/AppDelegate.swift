import AppKit
import KeyboardShortcuts
import Sparkle
import UserNotifications
import WakefulCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// For Shortcuts intents, which the system runs in this process.
    private(set) static weak var shared: AppDelegate?

    private let defaults = UserDefaults.standard
    #if DEBUG
    let updater = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    #else
    let updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    #endif
    private let assertion = PowerAssertion()
    private lazy var session = Session(assertion: assertion)
    private var statusItem: StatusItemController?
    private var powerMonitor: PowerSourceMonitor?
    private var lockMonitor: ScreenLockMonitor?
    private var deadlineTask: Task<Void, Never>?
    private var napGuard: NSObjectProtocol?

    override init() {
        super.init()
        Self.shared = self
    }

    var defaultDuration: SessionDuration { SessionDuration(storedValue: defaults.double(forKey: SettingsKey.defaultDuration)) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.shared.info("Launched \(Bundle.main.versionString)")
        defaults.register(defaults: DefaultSettings.registration)
        applySettings()
        session.onChange = { [weak self] in self?.sessionChanged() }
        session.onEnd = { [weak self] reason in self?.sessionEnded(reason) }

        session.powerSourceChanged(onBattery: PowerSourceMonitor.isOnBattery)
        powerMonitor = PowerSourceMonitor { [weak self] onBattery in
            Log.shared.info("Power source: \(onBattery ? "battery" : "AC")")
            self?.session.powerSourceChanged(onBattery: onBattery)
        }
        session.isScreenLocked = ScreenLockMonitor.isLocked
        lockMonitor = ScreenLockMonitor { [weak self] locked in self?.session.isScreenLocked = locked }

        // The system can drop assertions across sleep and user switches; put ours back if so.
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    Log.shared.info("Checking power assertion after \(name.rawValue)")
                    self?.assertion.ensureHeld()
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: defaults, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.applySettings() } }

        statusItem = StatusItemController(delegate: self)
        publishState()
        KeyboardShortcuts.onKeyUp(for: .toggleWakeful) { [weak self] in self?.toggle() }
        if defaults.bool(forKey: SettingsKey.activateAtLaunch) { activate(nil) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        session.deactivate()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let command = Command(url: url) else {
                Log.shared.error("Ignored invalid URL: \(url.absoluteString)")
                continue
            }
            Log.shared.info("URL command: \(command)")
            switch command {
            case .activate(let duration): activate(duration)
            case .deactivate: deactivate()
            case .toggle(let duration): toggle(duration)
            case .openSettings: WindowPresenter.shared.showSettings()
            }
        }
    }

    // MARK: Actions used by the menu

    var isActive: Bool { session.isActive }
    var endsAt: ContinuousClock.Instant? { session.endsAt }
    var duration: SessionDuration? { session.duration }

    /// `keepDisplayAwake` overrides the setting for this session only. Nil: see `Session.activate`.
    func activate(_ duration: SessionDuration?, keepDisplayAwake: Bool? = nil) {
        session.activate(duration ?? defaultDuration, now: .now, keepDisplayAwake: keepDisplayAwake)
    }

    func deactivate() { session.deactivate() }

    func toggle(_ duration: SessionDuration? = nil, keepDisplayAwake: Bool? = nil) {
        session.toggle(duration ?? defaultDuration, now: .now, keepDisplayAwake: keepDisplayAwake)
    }

    /// Whether the display stays awake right now: the session's own choice, or else the setting.
    var keepsDisplayAwake: Bool { session.keepsDisplayAwake }

    /// From the menu: sets the setting and drops any per-session choice, so the click always has an effect.
    func setKeepDisplayAwake(_ value: Bool) {
        session.clearDisplayOverride()
        defaults.set(value, forKey: SettingsKey.keepDisplayAwake)
    }

    func adjust(by seconds: TimeInterval) -> Bool { session.adjust(by: seconds, now: .now) }

    var remaining: Duration? { session.remaining(now: .now) }

    // MARK: Private

    private func applySettings() {
        session.keepDisplayAwake = defaults.bool(forKey: SettingsKey.keepDisplayAwake)
        session.lockBehavior = LockBehavior(rawValue: defaults.string(forKey: SettingsKey.lockBehavior) ?? "") ?? DefaultSettings.lockBehavior
        session.deactivateOnBattery = defaults.bool(forKey: SettingsKey.deactivateOnBattery)
        statusItem?.refresh()
    }

    private func sessionChanged() {
        let remaining = session.remaining(now: .now).map { "\(Int($0.components.seconds))s" } ?? "indefinite"
        Log.shared.info(session.isActive ? "Session active: \(remaining)" : "Session ended")
        statusItem?.refresh()
        publishState()
        deadlineTask?.cancel()
        if let napGuard { ProcessInfo.processInfo.endActivity(napGuard) }
        napGuard = nil
        guard let endsAt = session.endsAt else { return }
        // App Nap delays timers in background apps; this keeps the end time on schedule.
        napGuard = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep, reason: "Timed keep-awake session")
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(until: endsAt, tolerance: .milliseconds(200), clock: .continuous)
            guard !Task.isCancelled else { return }
            self?.session.update(now: .now)
        }
        if defaults.bool(forKey: SettingsKey.notifyWhenSessionEnds) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    /// For `wakeful status`.
    private func publishState() {
        defaults.set(session.isActive, forKey: StateKey.isActive)
        let endsAt = session.remaining(now: .now).map { left in
            let end = Date.now.addingTimeInterval(Double(left.components.seconds) + Double(left.components.attoseconds) / 1e18)
            return Date(timeIntervalSinceReferenceDate: end.timeIntervalSinceReferenceDate.rounded())
        }
        defaults.set(endsAt, forKey: StateKey.endsAt)
        defaults.set(Date.now, forKey: StateKey.updatedAt)
    }

    private func sessionEnded(_ reason: EndReason) {
        Log.shared.info("Session end reason: \(reason)")
        guard reason != .user, defaults.bool(forKey: SettingsKey.notifyWhenSessionEnds) else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Wakeful is off")
        content.body = reason == .switchedToBattery
            ? String(localized: "You unplugged the charger. Your Mac can sleep normally now.")
            : String(localized: "The session ended. Your Mac can sleep normally now.")
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}

extension Bundle {
    var versionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

extension KeyboardShortcuts.Name {
    static let toggleWakeful = Self("toggleWakeful")
}
