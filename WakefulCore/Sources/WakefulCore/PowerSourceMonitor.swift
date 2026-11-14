import Foundation
import IOKit.ps

/// Reports AC vs battery now and on every change. Lives as long as the app.
@MainActor
public final class PowerSourceMonitor {
    private var source: CFRunLoopSource?
    private let onChange: @MainActor (_ onBattery: Bool) -> Void

    public static var isOnBattery: Bool {
        let type = IOPSGetProvidingPowerSourceType(nil)?.takeUnretainedValue() as String?
        return type == kIOPSBatteryPowerValue
    }

    public init(onChange: @escaping @MainActor (_ onBattery: Bool) -> Void) {
        self.onChange = onChange
        let context = Unmanaged.passUnretained(self).toOpaque()
        source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<PowerSourceMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.onChange(PowerSourceMonitor.isOnBattery) }
        }, context)?.takeRetainedValue()
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode) }
    }
}
