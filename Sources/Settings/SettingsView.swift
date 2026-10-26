import AppKit
import ServiceManagement
import SwiftUI
import Translation

struct SettingsView: View {
    @Bindable private var prefs = Preferences.shared
    @State private var packStatus: LanguageAvailability.Status?
    @State private var downloadConfig: TranslationSession.Configuration?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var psnSignedIn = false
    @State private var sources = Language.sources
    @State private var targets = Language.targets

    var body: some View {
        Form {
            Section(S.general) {
                Picker(S.appLanguage, selection: $prefs.appLanguage) {
                    Text(AppLanguage.system.nativeName).tag(AppLanguage.system)
                    Divider()
                    ForEach(AppLanguage.allCases.filter { $0 != .system }) { language in
                        Text(language.nativeName).tag(language)
                    }
                }
                Toggle(S.launchAtLogin, isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    }
            }

            Section(S.translation) {
                Picker(S.subtitleLanguage, selection: $prefs.sourceLanguage) {
                    ForEach(sources, id: \.self) { Text(S.languageName($0)).tag($0) }
                }
                Picker(S.translateInto, selection: $prefs.targetLanguage) {
                    ForEach(targets, id: \.self) { Text(S.languageName($0)).tag($0) }
                }
                HStack {
                    Text(S.languagePack)
                    Spacer()
                    switch packStatus {
                    case .installed: Label(S.ready, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    case .supported:
                        Button(S.downloadPack) {
                            downloadConfig = TranslationSession.Configuration(
                                source: Locale.Language(identifier: prefs.sourceLanguage),
                                target: Locale.Language(identifier: prefs.targetLanguage))
                        }
                    case .unsupported: Text(S.pairUnsupported).foregroundStyle(.secondary)
                    default: ProgressView().controlSize(.small)
                    }
                }
            }

            Section(S.liveTranslation) {
                Toggle(S.coverOriginal, isOn: $prefs.coverOriginal)
                HStack {
                    Text(S.backgroundOpacity)
                    Slider(value: $prefs.subtitleBackground, in: 0...1, step: 0.05)
                    Text(S.percent(prefs.subtitleBackground)).monospacedDigit().frame(width: 44)
                }
                HStack {
                    Text(S.textSize)
                    Slider(value: $prefs.subtitleFontSize, in: 14...36, step: 1)
                    Text(verbatim: "\(Int(prefs.subtitleFontSize))").monospacedDigit().frame(width: 28)
                }
                Picker(S.whenRemotePlayOpens, selection: $prefs.remotePlayAction) {
                    Text(S.remotePlayAsk).tag(RemotePlayAction.ask)
                    Text(S.remotePlayStart).tag(RemotePlayAction.start)
                    Text(S.remotePlayNothing).tag(RemotePlayAction.nothing)
                }
                Text(S.followRemotePlayHint)
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(S.recognition) {
                Toggle(S.accurateRecognition, isOn: $prefs.accurateRecognition)
                Text(S.accurateRecognitionHint).font(.caption).foregroundStyle(.secondary)
                Toggle(S.debugRecording, isOn: $prefs.debugRecording)
                Text(S.debugRecordingHint).font(.caption).foregroundStyle(.secondary)
                Button(S.openDebugFolder) { DebugRecorder.shared.openFolder() }
            }

            Section(S.controller) {
                Toggle(S.batteryAlerts, isOn: $prefs.batteryAlerts)
            }

            Section(S.trophies) {
                if psnSignedIn {
                    Button(S.disconnectPSN, role: .destructive) {
                        Task {
                            await TrophyStore.shared.signOut()
                            psnSignedIn = false
                        }
                    }
                } else {
                    Text(S.connectPSNHint).foregroundStyle(.secondary)
                }
            }

            Section(S.shortcuts) {
                ForEach(HotKeys.Action.allCases, id: \.rawValue) { action in
                    LabeledContent(action.title) { ShortcutRecorder(action: action) }
                }
                Text(S.shortcutHint).font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 560)
        .task(id: "\(prefs.sourceLanguage)>\(prefs.targetLanguage)") {
            packStatus = nil
            packStatus = await Translator.status(from: prefs.sourceLanguage, to: prefs.targetLanguage)
        }
        .task { psnSignedIn = await PSNClient.shared.isSignedIn }
        .task {
            sources = await Language.systemSources()
            targets = await Language.systemTargets()
        }
        .translationTask(downloadConfig) { session in
            try? await session.prepareTranslation()
            let status = await Translator.status(from: prefs.sourceLanguage, to: prefs.targetLanguage)
            await MainActor.run { packStatus = status }
        }
    }
}

extension HotKeys.Action {
    var title: String {
        switch self {
        case .toggleLive: return S.toggleLive
        case .translateArea: return S.translateArea.replacingOccurrences(of: "…", with: "")
        case .subtitleLog: return S.subtitleLog
        case .trophies: return S.trophies
        }
    }
}

/// Click, then press the new combination. Esc cancels; the arrow restores the default.
private struct ShortcutRecorder: View {
    let action: HotKeys.Action
    @State private var label = ""
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button {
                recording ? stop() : start()
            } label: {
                Text(recording ? S.pressShortcut : label).monospaced().frame(minWidth: 110)
            }
            .buttonStyle(.bordered)
            if label != action.defaultCombo.label {
                Button {
                    HotKeys.shared.change(action, to: nil)
                    label = action.combo.label
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .help(S.restoreDefault)
            }
        }
        .onAppear { label = action.combo.label }
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        HotKeys.shared.suspend(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {  // Esc
                stop()
            } else if let combo = HotKeys.Combo(event: event) {
                HotKeys.shared.change(action, to: combo)
                label = combo.label
                stop()
            }
            return nil
        }
    }

    private func stop() {
        guard recording else { return }
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        HotKeys.shared.suspend(false)
    }
}
