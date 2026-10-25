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

    var body: some View {
        Button(app.isLive ? "Canlı çeviriyi durdur" : "Canlı çeviriyi başlat") { app.toggleLive() }
            .keyboardShortcut("l", modifiers: [.control, .option])
        Button("Canlı çeviri: yeni alan seç…") { app.startLive(reselect: true) }
        Button("Bir alanı çevir…") { app.translateArea() }
            .keyboardShortcut("t", modifiers: [.control, .option])
        Divider()
        Button("Altyazı geçmişi") { app.showSubtitleLog() }
            .keyboardShortcut("h", modifiers: [.control, .option])
        Button("Kupalar") { app.showTrophies() }
            .keyboardShortcut("k", modifiers: [.control, .option])
        Divider()
        Text(controller.summary.map { "🎮 \($0)" } ?? "🎮 Kumanda bağlı değil")
        Divider()
        Button("Ayarlar…") { app.showSettings() }
            .keyboardShortcut(",")
        Button("Çık") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
