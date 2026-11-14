import CoreGraphics
import Foundation

/// Reports screen lock and unlock (lives as long as the app). Uses the `com.apple.screenIsLocked` / `screenIsUnlocked`
/// distributed notifications, and `CGSessionCopyCurrentDictionary` for the state at start.
@MainActor
public final class ScreenLockMonitor {
    private var observers: [NSObjectProtocol] = []

    public static var isLocked: Bool {
        let info = CGSessionCopyCurrentDictionary() as? [String: Any]
        return info?["CGSSessionScreenIsLocked"] as? Bool ?? false
    }

    public init(onChange: @escaping @MainActor (_ locked: Bool) -> Void) {
        let center = DistributedNotificationCenter.default()
        for (name, locked) in [("com.apple.screenIsLocked", true), ("com.apple.screenIsUnlocked", false)] {
            observers.append(center.addObserver(forName: .init(name), object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { onChange(locked) }
            })
        }
    }
}
