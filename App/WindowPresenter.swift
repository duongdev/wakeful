import AppKit
import SwiftUI

/// Opens the Settings and Logs windows. A menu bar app has no Dock icon, so it must activate itself.
@MainActor
final class WindowPresenter {
    static let shared = WindowPresenter()
    private var windows: [String: NSWindow] = [:]

    func showSettings() {
        show(id: "settings", title: String(localized: "Wakeful Settings"), view: SettingsView())
    }

    func showLogs() {
        show(id: "logs", title: String(localized: "Wakeful Logs"), view: LogsView(), resizable: true)
    }

    private func show(id: String, title: String, view: some View, resizable: Bool = false) {
        let window = windows[id] ?? {
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = title
            window.styleMask = resizable ? [.titled, .closable, .resizable] : [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            windows[id] = window
            return window
        }()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
