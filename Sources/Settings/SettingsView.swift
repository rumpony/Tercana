import ServiceManagement
import SwiftUI
import Translation

struct SettingsView: View {
    @Bindable private var prefs = Preferences.shared
    @State private var packStatus: LanguageAvailability.Status?
    @State private var downloadConfig: TranslationSession.Configuration?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var psnSignedIn = false

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
                    ForEach(Language.sources, id: \.self) { Text(S.languageName($0)).tag($0) }
                }
                Picker(S.translateInto, selection: $prefs.targetLanguage) {
                    ForEach(Language.targets, id: \.self) { Text(S.languageName($0)).tag($0) }
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
                    LabeledContent(action.title, value: action.combo.label)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 560)
        .task(id: "\(prefs.sourceLanguage)>\(prefs.targetLanguage)") {
            packStatus = nil
            packStatus = await Translator.status(from: prefs.sourceLanguage, to: prefs.targetLanguage)
        }
        .task { psnSignedIn = await PSNClient.shared.isSignedIn }
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
