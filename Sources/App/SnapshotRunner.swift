import AppKit
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

/// Self-test for the interface: `SubLens --snapshot <folder>` opens every window and trophy page,
/// saves a PNG of each, then quits. Lets layout problems be checked without clicking through by hand.
@MainActor
enum SnapshotRunner {
    static var requestedFolder: URL? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--snapshot"), index + 1 < args.count else { return nil }
        return URL(fileURLWithPath: args[index + 1], isDirectory: true)
    }

    static func run(into folder: URL) async {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let app = AppController.shared

        app.showSettings()
        await capture("settings", into: folder, window: "settings")
        app.showSubtitleLog()
        await capture("subtitle-log", into: folder, window: "log")

        app.showTrophies()
        await pause(8)
        let store = TrophyStore.shared
        let pages: [(String, TrophyStore.Page)] = [
            ("profile", .profile), ("stats", .stats), ("closest", .closest),
            ("recent", .recent), ("platinums", .platinums), ("targets", .targets),
        ]
        for (name, page) in pages {
            await store.open(page)
            await capture("trophies-\(name)", into: folder, wait: page == .recent ? 10 : 2, window: "trophies")
        }
        if let game = store.closestGames.first ?? store.games.first {
            await store.open(.game(game.id))
            await capture("trophies-game", into: folder, wait: 4, window: "trophies")
        }
        // The smallest size the window allows, to catch anything that overflows.
        if let window = app.window(id: "trophies") {
            window.setContentSize(window.contentMinSize.width > 0 ? window.contentMinSize : CGSize(width: 900, height: 600))
            await capture("trophies-game-narrow", into: folder, window: "trophies")
        }

        let panel = SubtitlePanel()
        let screen = NSScreen.main!.visibleFrame
        let region = CGRect(x: screen.midX - 450, y: screen.minY + 120, width: 900, height: 90)
        panel.update(.subtitle("GAETANO: Bunu bana tekrar oku, yapabilir misin?"), region: region,
                     textRect: region.insetBy(dx: 180, dy: 25))
        await capture("subtitle-panel", into: folder, windowNumber: panel.windowNumber)

        NSApp.terminate(nil)
    }

    private static func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    /// Captures the frontmost SubLens window (or a given one) as it appears on screen.
    private static func capture(_ name: String, into folder: URL, wait: Double = 2, window id: String? = nil,
                                windowNumber: Int? = nil) async {
        await pause(wait)
        // Key windows draw their real control colors; inactive ones grey everything out.
        let target = id.flatMap { AppController.shared.window(id: $0) }
        if let target { NSApp.activate(); target.makeKeyAndOrderFront(nil); await pause(0.4) }
        let number = windowNumber ?? target?.windowNumber
        guard let number,
              let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
              let window = content.windows.first(where: { $0.windowID == CGWindowID(number) }) else { return }
        let config = SCStreamConfiguration()
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        config.width = Int(window.frame.width * scale)
        config.height = Int(window.frame.height * scale)
        config.showsCursor = false
        guard let image = try? await SCScreenshotManager.captureImage(
            contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: config) else { return }
        let url = folder.appendingPathComponent("\(name).png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
}
