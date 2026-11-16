import AppKit
import SwiftUI

/// Opens the Settings and Logs windows. A menu bar app has no Dock icon, so it must activate itself.
/// While one of these windows is open, Wakeful shows in the Dock and in Command-Tab, so a window
/// left behind others is easy to find.
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
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.windowWillClose(id: id) }
            }
            windows[id] = window
            return window
        }()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func windowWillClose(id closing: String) {
        if !windows.contains(where: { $0.key != closing && $0.value.isVisible }) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
