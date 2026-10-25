import SwiftUI

@main
struct SubLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            Image(systemName: AppController.shared.isLive ? "captions.bubble.fill" : "captions.bubble")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated { AppController.shared.launch() }
    }
}

private struct MenuContent: View {
    private let app = AppController.shared
    private let controller = ControllerWatch.shared
    private let prefs = Preferences.shared

    var body: some View {
        // Reading the language here makes the menu rebuild when it changes.
        let _ = prefs.appLanguage
        Button(app.isLive ? S.stopLive : S.startLive) { app.toggleLive() }
            .keyboardShortcut("l", modifiers: [.control, .option])
        Button(S.newLiveArea) { app.startLive(reselect: true) }
        Button(S.translateArea) { app.translateArea() }
            .keyboardShortcut("t", modifiers: [.control, .option])
        Divider()
        Button(S.subtitleLog) { app.showSubtitleLog() }
            .keyboardShortcut("h", modifiers: [.control, .option])
        Button(S.trophies) { app.showTrophies() }
            .keyboardShortcut("k", modifiers: [.control, .option])
        Divider()
        Text("🎮 " + (controller.summary ?? S.noController))
        Divider()
        Button(S.settings) { app.showSettings() }
            .keyboardShortcut(",")
        Button(S.quit) { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
