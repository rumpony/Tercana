import AppKit
import Observation
import SwiftUI

/// Wires features together and owns the windows.
@MainActor
@Observable
final class AppController {
    static let shared = AppController()

    private(set) var isLive = false

    @ObservationIgnored private let prefs = Preferences.shared
    @ObservationIgnored private let picker = AreaPicker()
    @ObservationIgnored private let resultCard = ResultCard()
    @ObservationIgnored private let remotePlay = RemotePlayWatcher()
    @ObservationIgnored private var live: LiveTranslator?
    @ObservationIgnored private var frame: RegionFrame?
    @ObservationIgnored private var subtitle: SubtitlePanel?
    @ObservationIgnored private var windows: [String: NSWindow] = [:]
    /// Auto-start happens once per Remote Play launch, so stopping by hand sticks.
    @ObservationIgnored private var autoStarted = false

    func launch() {
        HotKeys.shared.register(.toggleLive) { [weak self] in self?.toggleLive() }
        HotKeys.shared.register(.translateArea) { [weak self] in self?.translateArea() }
        HotKeys.shared.register(.subtitleLog) { [weak self] in self?.showSubtitleLog() }
        HotKeys.shared.register(.trophies) { [weak self] in self?.showTrophies() }

        remotePlay.onActivate = { [weak self] in
            guard let self, self.prefs.followRemotePlay, !self.autoStarted, !self.isLive,
                  self.prefs.liveRegion != nil else { return }
            self.autoStarted = true
            self.startLive(reselect: false)
        }
        remotePlay.onQuit = { [weak self] in
            guard let self else { return }
            self.autoStarted = false
            if self.prefs.followRemotePlay { self.stopLive() }
        }
        remotePlay.start()
        ControllerWatch.shared.start()

        if !ScreenGrabber.hasPermission { ScreenGrabber.requestPermission() }
    }

    // MARK: Live translation

    func toggleLive() {
        isLive ? stopLive() : startLive(reselect: false)
    }

    func startLive(reselect: Bool) {
        if isLive { stopLive() }
        guard ScreenGrabber.hasPermission else {
            ScreenGrabber.requestPermission()
            Toast.show("Önce ekran kaydı izni ver, sonra tekrar dene.", symbol: "lock.shield")
            return
        }
        if !reselect, let saved = prefs.liveRegion, NSScreen.screens.contains(where: { $0.frame.contains(saved) }) {
            beginLive(in: saved)
            return
        }
        picker.pick(hint: "Altyazı alanını sürükleyerek seç  ·  Esc: vazgeç") { [weak self] rect in
            guard let self, let rect else { return }
            self.prefs.liveRegion = rect
            self.beginLive(in: rect)
        }
    }

    func stopLive() {
        live?.stop()
    }

    private func beginLive(in region: CGRect) {
        let live = LiveTranslator(region: region)
        let frame = RegionFrame(region: region)
        let subtitle = SubtitlePanel()

        live.onStateChange = { [weak live, weak subtitle] state in
            guard let live else { return }
            subtitle?.update(state, region: live.region)
        }
        live.onStop = { [weak self] reason in
            self?.endLive()
            if let reason { Toast.show(reason, symbol: "exclamationmark.triangle") }
        }
        frame.onChange = { [weak self, weak live] rect in
            live?.region = rect
            self?.prefs.liveRegion = rect
        }
        frame.onClose = { [weak self] in self?.stopLive() }

        self.live = live
        self.frame = frame
        self.subtitle = subtitle
        isLive = true
        frame.show()
        live.start()
    }

    private func endLive() {
        frame?.close()
        subtitle?.close()
        live = nil
        frame = nil
        subtitle = nil
        isLive = false
    }

    // MARK: One-off area translation

    func translateArea() {
        guard ScreenGrabber.hasPermission else {
            ScreenGrabber.requestPermission()
            return
        }
        picker.pick(hint: "Çevrilecek alanı seç  ·  Esc: vazgeç") { [weak self] rect in
            guard let self, let rect else { return }
            Task { await self.translate(area: rect) }
        }
    }

    private func translate(area: CGRect) async {
        // Give the picker a moment to leave the screen before capturing.
        try? await Task.sleep(for: .milliseconds(120))
        var original = ""
        do {
            let image = try await ScreenGrabber.shared.capture(area)
            original = try await TextReader.read(image, language: prefs.sourceLanguage, quality: .accurate)
                .replacingOccurrences(of: "\n", with: " ")
            guard !original.isEmpty else {
                resultCard.show(original: "", translation: nil, error: nil, near: area)
                return
            }
            let translated = try await Translator.shared.translate(original, from: prefs.sourceLanguage,
                                                                  to: prefs.targetLanguage)
            resultCard.show(original: original, translation: translated, error: nil, near: area)
        } catch {
            resultCard.show(original: original, translation: nil, error: error.localizedDescription, near: area)
        }
    }

    // MARK: Windows

    func showSubtitleLog() {
        present(id: "log", title: "Altyazı Geçmişi", size: CGSize(width: 520, height: 600)) { SubtitleLogView() }
    }

    func showTrophies() {
        present(id: "trophies", title: "Kupalar", size: CGSize(width: 980, height: 680)) { TrophiesView() }
    }

    func showSettings() {
        present(id: "settings", title: "SubLens Ayarları", size: CGSize(width: 520, height: 560)) { SettingsView() }
    }

    private func present<V: View>(id: String, title: String, size: CGSize, content: () -> V) {
        if let window = windows[id] {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content())
        window.center()
        windows[id] = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
