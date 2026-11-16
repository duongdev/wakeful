import SwiftUI

@main
struct WakefulApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The menu bar item and windows are managed by AppDelegate (AppKit),
        // because SwiftUI's MenuBarExtra cannot tell left from right clicks.
        Settings { EmptyView() }
            .commands {
                // The app menu shows while a window is open; open our own Settings window.
                CommandGroup(replacing: .appSettings) {
                    Button("Settings…") { WindowPresenter.shared.showSettings() }
                        .keyboardShortcut(",")
                }
            }
    }
}
