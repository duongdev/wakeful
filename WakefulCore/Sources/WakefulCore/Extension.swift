import AppKit

/// A paid feature. The free app shows its setting locked; an extension unlocks it.
public enum ProFeature: String, Sendable {
    case resumeOnPlugIn
    case lidClosedMode
}

/// Adds behavior to the app. A build may include one Objective-C class named
/// `WakefulExtension` that conforms; the app creates it at launch.
@MainActor
public protocol WakefulExtension: AnyObject {
    var unlockedFeatures: Set<ProFeature> { get }
    func start(session: Session)
    /// Items the extension adds near the end of the menu bar menu. Called each time the menu opens.
    func addMenuItems(to menu: NSMenu)
}

public enum Extensions {
    @MainActor
    public static func load() -> (any WakefulExtension)? {
        (NSClassFromString("WakefulExtension") as? NSObject.Type)?.init() as? any WakefulExtension
    }
}
