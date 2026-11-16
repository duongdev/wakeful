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
        item.button?.imagePosition = .imageOnly
        refresh()
    }

    func refresh() {
        item.button?.appearsDisabled = !delegate.isActive && defaults.bool(forKey: SettingsKey.dimIconWhenInactive)
        updateCountdown()
    }

    // MARK: Icon and countdown

    private func updateCountdown() {
        let active = delegate.isActive
        var timeLeft: String?
        if defaults.bool(forKey: SettingsKey.showTimeLeftInMenuBar), let endsAt = delegate.endsAt {
            timeLeft = DurationText.short(ContinuousClock.now.duration(to: endsAt))
            if countdownTimer == nil {
                countdownTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated { self?.updateCountdown() }
                }
            }
        } else {
            countdownTimer?.invalidate()
            countdownTimer = nil
        }
        let style = active
            ? ActiveIconStyle(rawValue: defaults.string(forKey: SettingsKey.activeIconStyle) ?? "") ?? DefaultSettings.activeIconStyle
            : .standard
        item.button?.image = Self.menuBarImage(active: active, timeLeft: timeLeft, style: style)
        let label = switch (active, timeLeft) {
        case (false, _): String(localized: "Wakeful: off")
        case (true, nil): String(localized: "Wakeful: on")
        case (true, let timeLeft?): String(localized: "Wakeful: on, \(timeLeft) left")
        }
        item.button?.setAccessibilityLabel(label)
    }

    /// The time left is drawn into the image, not set as the button title: a titled status
    /// button gets 2 pt more padding at each end than an image-only one, which pushes the icon
    /// away from its neighbors.
    ///
    /// The standard style is a template image, so the system tints it. The colored styles cannot be
    /// templates; they draw the parts that follow the menu bar in `labelColor`, which resolves for the
    /// menu bar's appearance when the image draws.
    private static func menuBarImage(active: Bool, timeLeft: String?, style: ActiveIconStyle) -> NSImage? {
        guard let glyph = NSImage(named: active ? "MenuBarActive" : "MenuBarInactive") else { return nil }
        // 16 pt glyph on an 18 pt wide canvas, placed so the cup and handle (not the thin
        // saucer tip) are centered. The clear sides match the inner margin of other icons.
        let glyphSize = NSSize(width: 18, height: 16)
        glyph.size = glyphSize
        if style == .standard && timeLeft == nil { return glyph }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
        ]
        let textSize = timeLeft.map { ($0 as NSString).size(withAttributes: attributes) } ?? .zero
        let gap: CGFloat = timeLeft == nil ? 0 : 4
        let size = NSSize(
            width: glyphSize.width + gap + ceil(textSize.width),
            height: max(glyphSize.height, ceil(textSize.height)))
        let accent: NSColor? = switch style {
        case .standard: nil
        case .green, .greenDot: .systemGreen
        case .blue, .blueDot: .systemBlue
        }
        let image = NSImage(size: size, flipped: false) { _ in
            let glyphRect = NSRect(origin: NSPoint(x: 0, y: (size.height - glyphSize.height) / 2), size: glyphSize)
            let ink: NSColor = switch style {
            case .standard: .black
            case .green, .blue: accent ?? .labelColor
            case .greenDot, .blueDot: .labelColor
            }
            tinted(glyph, ink).draw(in: glyphRect)
            if style == .greenDot || style == .blueDot, let accent {
                // A badge dot at the top-right, with a clear ring so it stays apart from the handle.
                let dot = NSRect(x: glyphRect.maxX - 5, y: glyphRect.maxY - 5, width: 5, height: 5)
                NSGraphicsContext.current?.compositingOperation = .clear
                NSBezierPath(ovalIn: dot.insetBy(dx: -1, dy: -1)).fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
                accent.setFill()
                NSBezierPath(ovalIn: dot).fill()
            }
            if let timeLeft {
                var textAttributes = attributes
                textAttributes[.foregroundColor] = style == .standard ? NSColor.black : NSColor.labelColor
                (timeLeft as NSString).draw(
                    at: NSPoint(x: glyphSize.width + gap, y: (size.height - textSize.height) / 2),
                    withAttributes: textAttributes)
            }
            return true
        }
        image.isTemplate = style == .standard
        return image
    }

    /// The glyph's shape filled with one color.
    private static func tinted(_ glyph: NSImage, _ color: NSColor) -> NSImage {
        NSImage(size: glyph.size, flipped: false) { rect in
            glyph.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
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
        menu.addItem(active ? action(String(localized: "Turn Off"), #selector(turnOff)) : turnOnItem())
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
        menu.addItem(action(String(localized: "Until a Time…"), #selector(chooseUntil)))
        menu.addItem(.separator())

        let display = action(String(localized: "Keep Display Awake"), #selector(toggleDisplayAwake))
        display.state = delegate.keepsDisplayAwake ? .on : .off
        menu.addItem(display)
        if Hardware.hasLid {
            let lid = action(String(localized: "Keep Awake with Lid Closed"), #selector(toggleLidClosedMode))
            if delegate.unlockedFeatures.contains(.lidClosedMode) {
                lid.state = defaults.bool(forKey: SettingsKey.lidClosedMode) ? .on : .off
            } else {
                lid.action = nil
                lid.badge = NSMenuItemBadge(string: "Pro")
            }
            menu.addItem(lid)
        }
        menu.addItem(.separator())

        menu.addItem(action(String(localized: "Settings…"), #selector(openSettings), key: ","))
        let help = NSMenuItem(title: String(localized: "Help"), action: nil, keyEquivalent: "")
        help.submenu = helpMenu()
        menu.addItem(help)
        delegate.addExtensionMenuItems(to: menu)
        menu.addItem(.separator())
        menu.addItem(action(String(localized: "Quit Wakeful"), #selector(quit), key: "q"))
    }

    private func helpMenu() -> NSMenu {
        let help = NSMenu()
        help.addItem(action(String(localized: "About Wakeful"), #selector(about)))
        let updates = NSMenuItem(title: String(localized: "Check for Updates…"), action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updates.target = delegate.updater
        help.addItem(updates)
        help.addItem(action(String(localized: "Release Notes"), #selector(releaseNotes)))
        help.addItem(action(String(localized: "URL Scheme Help"), #selector(urlSchemeHelp)))
        help.addItem(.separator())
        help.addItem(action(String(localized: "Report a Bug…"), #selector(reportBug)))
        return help
    }

    /// Turns on with the default duration, so the most common action is one click.
    private func turnOnItem() -> NSMenuItem {
        let duration = delegate.defaultDuration
        let title = duration == .indefinite
            ? String(localized: "Turn On Indefinitely")
            : String(localized: "Turn On for \(DurationText.label(duration))")
        return action(title, #selector(turnOn))
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

    @objc private func turnOn() { delegate.activate(nil) }

    @objc private func turnOff() { delegate.deactivate() }

    @objc private func choosePreset(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        delegate.activate(SessionDuration(storedValue: value))
    }

    @objc private func chooseCustom() {
        if let duration = CustomDurationPrompt.run() { delegate.activate(duration) }
    }

    @objc private func chooseUntil() {
        if let duration = CustomDurationPrompt.runUntil() { delegate.activate(duration) }
    }

    @objc private func toggleDisplayAwake() {
        delegate.setKeepDisplayAwake(!delegate.keepsDisplayAwake)
    }

    @objc private func toggleLidClosedMode() {
        defaults.set(!defaults.bool(forKey: SettingsKey.lidClosedMode), forKey: SettingsKey.lidClosedMode)
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
