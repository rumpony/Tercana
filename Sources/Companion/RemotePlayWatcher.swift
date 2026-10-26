import AppKit

/// Tells the app when PS Remote Play comes to the front or quits.
@MainActor
final class RemotePlayWatcher {
    nonisolated static let bundleID = "com.playstation.RemotePlay"

    var onActivate: (() -> Void)?
    var onQuit: (() -> Void)?
    private var tokens: [NSObjectProtocol] = []

    static var isFrontmost: Bool {
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        // Our own panels and pickers count as "still in the game".
        return front == bundleID || front == Bundle.main.bundleIdentifier
    }

    static var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        tokens.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                         object: nil, queue: .main) { [weak self] note in
            guard Self.isRemotePlay(note) else { return }
            MainActor.assumeIsolated { self?.onActivate?() }
        })
        tokens.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                                         object: nil, queue: .main) { [weak self] note in
            guard Self.isRemotePlay(note) else { return }
            MainActor.assumeIsolated { self?.onQuit?() }
        })
    }

    nonisolated private static func isRemotePlay(_ note: Notification) -> Bool {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        return app?.bundleIdentifier == bundleID
    }
}
