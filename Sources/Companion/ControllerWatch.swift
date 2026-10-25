import Foundation
import GameController
import Observation

/// Tracks the connected controller's battery and warns when it runs low.
@MainActor
@Observable
final class ControllerWatch {
    static let shared = ControllerWatch()

    private(set) var name: String?
    private(set) var batteryLevel: Float?
    private(set) var isCharging = false

    private var timer: Timer?
    private var warnedAt: Float?

    func start() {
        GCController.shouldMonitorBackgroundEvents = true
        let center = NotificationCenter.default
        center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { ControllerWatch.shared.refresh() }
        }
        center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { ControllerWatch.shared.refresh() }
        }
        GCController.startWirelessControllerDiscovery()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            MainActor.assumeIsolated { ControllerWatch.shared.refresh() }
        }
        refresh()
    }

    /// Short text for the menu, e.g. "DualSense · %42".
    var summary: String? {
        guard let name else { return nil }
        guard let batteryLevel else { return name }
        return "\(name) · \(S.percent(Double(batteryLevel)))\(isCharging ? " ⚡︎" : "")"
    }

    private func refresh() {
        guard let controller = GCController.controllers().first else {
            name = nil
            batteryLevel = nil
            return
        }
        name = controller.vendorName ?? S.controller
        if let battery = controller.battery, battery.batteryState != .unknown {
            batteryLevel = battery.batteryLevel
            isCharging = battery.batteryState == .charging || battery.batteryState == .full
        } else {
            batteryLevel = nil
        }
        checkLow()
    }

    private func checkLow() {
        guard Preferences.shared.batteryAlerts, let level = batteryLevel, !isCharging else {
            warnedAt = nil
            return
        }
        // Warn once at 15% and once more at 5%.
        for threshold: Float in [0.05, 0.15] where level <= threshold {
            if warnedAt == nil || warnedAt! > threshold {
                warnedAt = threshold
                Toast.show(S.batteryLow(level),
                           symbol: "battery.25percent", seconds: 6)
            }
            return
        }
    }
}
