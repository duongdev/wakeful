import AppKit
import Sparkle
import WakefulCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private unowned let delegate: AppDelegate
    private var countdownTimer: Timer?
    private let defaults = UserDefaults.standard

    private enum Link {
        static let releases = URL(string: "https://github.com/duongdev/wakeful/releases")!
        static let urlScheme = URL(string: "https://github.com/duongdev/wakeful#url-scheme")!
        static let newIssue = "https://github.com/duongdev/wakeful/issues/new"
    }

    init(delegate: AppDelegate) {
        self.delegate = delegate
        super.init()
        menu.delegate = self
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.imagePosition = .imageLeading
        refresh()
    }

    func refresh() {
        let active = delegate.isActive
        let image = NSImage(named: active ? "MenuBarActive" : "MenuBarInactive")
        // 16 pt square, centered: the same visual size as system menu bar icons.
        image?.size = NSSize(width: 16, height: 16)
        item.button?.image = image
        item.button?.setAccessibilityLabel(active ? String(localized: "Wakeful: on") : String(localized: "Wakeful: off"))
        item.button?.appearsDisabled = !active && defaults.bool(forKey: SettingsKey.dimIconWhenInactive)
        updateCountdown()
    }

    // MARK: Countdown next to the icon

    private func updateCountdown() {
        let show = defaults.bool(forKey: SettingsKey.showTimeLeftInMenuBar)
        guard show, let endsAt = delegate.endsAt else {
            countdownTimer?.invalidate()
            countdownTimer = nil
            item.button?.title = ""
            return
        }
        item.button?.title = " " + DurationText.short(ContinuousClock.now.duration(to: endsAt))
        item.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        if countdownTimer == nil {
            countdownTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateCountdown() }
            }
        }
    }

    // MARK: Clicks

    @objc private func clicked() {
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
        if defaults.bool(forKey: SettingsKey.toggleOnLeftClick) && !isRightClick {
            delegate.toggle()
        } else {
            item.menu = menu
            item.button?.performClick(nil)
            item.menu = nil
        }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let active = delegate.isActive

        #if DEBUG
        menu.addItem(.sectionHeader(title: "Wakeful Dev"))
        #endif
        menu.addItem(.sectionHeader(title: statusText()))
        if active { menu.addItem(action(String(localized: "Turn Off"), #selector(turnOff))) }
        menu.addItem(.separator())

        menu.addItem(.sectionHeader(title: active ? String(localized: "Change Duration") : String(localized: "Keep Awake")))
        let current = delegate.duration
        for preset in SessionDuration.presets {
            let entry = action(DurationText.label(preset), #selector(choosePreset(_:)))
            entry.representedObject = preset.storedValue
            entry.state = current == preset ? .on : .off
            menu.addItem(entry)
        }
        let isCustom = current.map { !SessionDuration.presets.contains($0) } ?? false
        let customTitle = isCustom
            ? String(localized: "Custom (\(DurationText.label(current!)))…")
            : String(localized: "Custom…")
        let custom = action(customTitle, #selector(chooseCustom))
        custom.state = isCustom ? .on : .off
        menu.addItem(custom)
        menu.addItem(.separator())

        let display = action(String(localized: "Keep Display Awake"), #selector(toggleDisplayAwake))
        display.state = defaults.bool(forKey: SettingsKey.keepDisplayAwake) ? .on : .off
        menu.addItem(display)
        menu.addItem(.separator())

        menu.addItem(action(String(localized: "Settings…"), #selector(openSettings), key: ","))
        let updates = NSMenuItem(title: String(localized: "Check for Updates…"), action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updates.target = delegate.updater
        menu.addItem(updates)
        let help = NSMenuItem(title: String(localized: "Help"), action: nil, keyEquivalent: "")
        help.submenu = helpMenu()
        menu.addItem(help)
        menu.addItem(.separator())
        menu.addItem(action(String(localized: "Quit Wakeful"), #selector(quit), key: "q"))
    }

    private func helpMenu() -> NSMenu {
        let help = NSMenu()
        help.addItem(action(String(localized: "About Wakeful"), #selector(about)))
        help.addItem(action(String(localized: "Release Notes"), #selector(releaseNotes)))
        help.addItem(action(String(localized: "URL Scheme Help"), #selector(urlSchemeHelp)))
        help.addItem(.separator())
        help.addItem(action(String(localized: "Report a Bug…"), #selector(reportBug)))
        return help
    }

    private func statusText() -> String {
        guard delegate.isActive else { return String(localized: "Off") }
        guard let endsAt = delegate.endsAt else { return String(localized: "On until turned off") }
        return DurationText.endsLabel(ContinuousClock.now.duration(to: endsAt))
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        entry.target = self
        return entry
    }

    // MARK: Actions

    @objc private func turnOff() { delegate.deactivate() }

    @objc private func choosePreset(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        delegate.activate(SessionDuration(storedValue: value))
    }

    @objc private func chooseCustom() {
        if let duration = CustomDurationPrompt.run() { delegate.activate(duration) }
    }

    @objc private func toggleDisplayAwake() {
        let current = defaults.bool(forKey: SettingsKey.keepDisplayAwake)
        defaults.set(!current, forKey: SettingsKey.keepDisplayAwake)
    }

    @objc private func openSettings() { WindowPresenter.shared.showSettings() }

    @objc private func about() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func releaseNotes() { NSWorkspace.shared.open(Link.releases) }

    @objc private func urlSchemeHelp() { NSWorkspace.shared.open(Link.urlScheme) }

    /// Copies the logs (too long for a URL) and opens a bug report with version fields filled in.
    @objc private func reportBug() {
        LogsView.copyToClipboard()
        var components = URLComponents(string: Link.newIssue)!
        components.queryItems = [
            URLQueryItem(name: "template", value: "bug_report.yml"),
            URLQueryItem(name: "version", value: Bundle.main.versionString),
            URLQueryItem(name: "macos", value: ProcessInfo.processInfo.operatingSystemVersionString),
            URLQueryItem(name: "logs", value: String(localized: "(Logs were copied to your clipboard. Paste them here.)")),
        ]
        if let url = components.url { NSWorkspace.shared.open(url) }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
