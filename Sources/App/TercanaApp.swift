import SwiftUI

@main
struct TercanaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        // Before anything reads settings or data.
        Migration.fromSubLens()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            Image(nsImage: BrandMark.menuBarImage(live: AppController.shared.isLive))
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
        Button(S.openTercana) { app.showHome() }
        Divider()
        Button(app.isLive ? S.stopLive : S.startLive) { app.toggleLive() }
        Button(S.newLiveArea) { app.startLive(reselect: true) }
        Button(S.translateArea) { app.translateArea() }
        Divider()
        Button(S.subtitleLog) { app.showSubtitleLog() }
        Button(S.trophies) { app.showTrophies() }
        Divider()
        Text("🎮 " + (controller.summary ?? S.noController))
        if prefs.debugRecording {
            Button("🔴 " + S.debugOn + " · " + S.openDebugFolder) { DebugRecorder.shared.openFolder() }
        }
        Divider()
        Button(S.settings) { app.showSettings() }
            .keyboardShortcut(",")
        Button(S.quit) { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
