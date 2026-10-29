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
    @ObservationIgnored private var windows: [String: (window: NSWindow, title: () -> String)] = [:]
    /// Auto-start happens once per Remote Play launch, so stopping by hand sticks.
    @ObservationIgnored private var autoStarted = false

    func launch() {
        HotKeys.shared.register(.toggleLive) { [weak self] in self?.toggleLive() }
        HotKeys.shared.register(.translateArea) { [weak self] in self?.translateArea() }
        HotKeys.shared.register(.subtitleLog) { [weak self] in self?.showSubtitleLog() }
        HotKeys.shared.register(.trophies) { [weak self] in self?.showTrophies() }

        remotePlay.onActivate = { [weak self] in
            // Once per Remote Play launch, so stopping or dismissing by hand sticks.
            guard let self, !self.autoStarted, !self.isLive else { return }
            self.autoStarted = true
            switch self.prefs.remotePlayAction {
            case .nothing: break
            case .start: self.startLive(reselect: self.prefs.liveRegion == nil)
            case .ask:
                Prompt.show(S.remotePlayPrompt, hint: S.remotePlayPromptHint, actions: [
                    (S.start, true, { [weak self] in self?.startLive(reselect: false) }),
                    (S.chooseArea, false, { [weak self] in self?.startLive(reselect: true) }),
                ])
            }
        }
        remotePlay.onQuit = { [weak self] in
            guard let self else { return }
            self.autoStarted = false
            Prompt.dismiss()
            if self.prefs.remotePlayAction != .nothing { self.stopLive() }
        }
        remotePlay.start()
        ControllerWatch.shared.start()

        if !ScreenGrabber.hasPermission { ScreenGrabber.requestPermission() }
        followLanguageChanges()
    }

    /// Window titles are plain AppKit strings; refresh them when the interface language changes.
    private func followLanguageChanges() {
        withObservationTracking {
            _ = prefs.appLanguage
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                for entry in self.windows.values { entry.window.title = entry.title() }
                self.followLanguageChanges()
            }
        }
    }

    // MARK: Live translation

    func toggleLive() {
        Prompt.dismiss()
        isLive ? stopLive() : startLive(reselect: false)
    }

    func startLive(reselect: Bool) {
        if isLive { stopLive() }
        guard ScreenGrabber.hasPermission else {
            ScreenGrabber.requestPermission()
            Toast.show(S.grantPermissionFirst, symbol: "lock.shield")
            return
        }
        if !reselect, let saved = prefs.liveRegion, NSScreen.screens.contains(where: { $0.frame.contains(saved) }) {
            beginLive(in: saved)
            return
        }
        picker.pick(hint: S.pickLiveArea) { [weak self] rect in
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
            subtitle?.update(state, region: live.region, textRect: live.textRect)
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
        picker.pick(hint: S.pickTranslateArea) { [weak self] rect in
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

    @ObservationIgnored let router = HomeRouter()

    /// Everything lives in one window; the menu and shortcuts just pick the tab.
    func showHome(_ tab: HomeView.Tab = .home) {
        withAnimation(.easeInOut(duration: 0.18)) { router.tab = tab }
        present(id: "home", title: { "Tercana" }, size: CGSize(width: 1040, height: 720)) { [router] in
            HomeView(router: router)
        }
    }

    func showSubtitleLog() { showHome(.history) }
    func showTrophies() { showHome(.trophies) }
    func showSettings() { showHome(.settings) }

    func window(id: String) -> NSWindow? { windows[id]?.window }

    private func present<V: View>(id: String, title: @escaping () -> String, size: CGSize,
                                  content: @escaping () -> V) {
        if let window = windows[id]?.window {
            bringForward(window)
            return
        }
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = title()
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: LocalizedRoot(content: content))
        // Let SwiftUI's minimum size bound the window, so it can't be shrunk until content spills out.
        host.sizingOptions = [.minSize]
        // SwiftUI toolbars reach the window, so every tab shares one toolbar (and one title bar height).
        host.sceneBridgingOptions = [.toolbars]
        window.contentView = host
        window.center()
        windows[id] = (window, title)
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window,
                                               queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.windowClosed() }
        }
        bringForward(window)
    }

    /// A menu-bar-only app can't keep a window active: its switches and buttons draw grey and it
    /// slips behind other apps. Act as a regular app while a window is open.
    private func bringForward(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func windowClosed() {
        // The closing window still counts as visible during this notification.
        DispatchQueue.main.async {
            let open = self.windows.values.filter { $0.window.isVisible }
            if open.isEmpty { NSApp.setActivationPolicy(.accessory) }
        }
    }
}

/// Rebuilds its content in the new language when the interface language changes,
/// and hands SwiftUI the matching locale for dates and numbers.
private struct LocalizedRoot<Content: View>: View {
    let content: () -> Content
    private let prefs = Preferences.shared

    var body: some View {
        content()
            .id(prefs.appLanguage)
            .environment(\.locale, prefs.appLanguage.locale)
    }
}
