import AppKit

/// The app's own language. It is stored where macOS keeps per-app languages (`AppleLanguages` in the
/// app's defaults), so it stays in sync with System Settings › General › Language & Region › Applications.
enum AppLanguage {
    static let available = ["en", "vi", "es", "fr", "de", "it", "pt-BR", "ru", "ja", "ko", "zh-Hans", "zh-Hant"]

    /// The chosen language, or "" to follow the system.
    static var current: String {
        guard let id = Bundle.main.bundleIdentifier,
              let stored = (UserDefaults.standard.persistentDomain(forName: id)?["AppleLanguages"] as? [String])?.first
        else { return "" }
        // System Settings may store a region too, like "vi-VN".
        return available.last { stored == $0 || stored.hasPrefix($0 + "-") } ?? ""
    }

    static func set(_ code: String) {
        if code.isEmpty {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        }
    }

    /// The language's name in that language, like "Tiếng Việt" or "日本語".
    static func name(_ code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forIdentifier: code)?.capitalized(with: locale) ?? code
    }

    /// macOS reads the language only at launch.
    static func relaunch() {
        let reopen = Process()
        reopen.executableURL = URL(fileURLWithPath: "/bin/sh")
        reopen.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? reopen.run()
        NSApp.terminate(nil)
    }
}
