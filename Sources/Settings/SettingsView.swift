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
            Section("Çeviri") {
                Picker("Altyazı dili", selection: $prefs.sourceLanguage) {
                    ForEach(Language.sources, id: \.code) { Text($0.name).tag($0.code) }
                }
                Picker("Çeviri dili", selection: $prefs.targetLanguage) {
                    ForEach(Language.targets, id: \.code) { Text($0.name).tag($0.code) }
                }
                HStack {
                    Text("Dil paketi")
                    Spacer()
                    switch packStatus {
                    case .installed: Label("Hazır", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    case .supported:
                        Button("Dil paketini indir") {
                            downloadConfig = TranslationSession.Configuration(
                                source: Locale.Language(identifier: prefs.sourceLanguage),
                                target: Locale.Language(identifier: prefs.targetLanguage))
                        }
                    case .unsupported: Text("Bu dil çifti desteklenmiyor").foregroundStyle(.secondary)
                    default: ProgressView().controlSize(.small)
                    }
                }
            }

            Section("Canlı çeviri") {
                Toggle("Çeviriyi orijinal altyazının üstüne yaz", isOn: $prefs.coverOriginal)
                HStack {
                    Text("Yazı boyutu")
                    Slider(value: $prefs.subtitleFontSize, in: 14...36, step: 1)
                    Text("\(Int(prefs.subtitleFontSize))").monospacedDigit().frame(width: 28)
                }
                Toggle("Remote Play açılınca otomatik başlat, kapanınca durdur", isOn: $prefs.followRemotePlay)
                Text("Otomatik başlatma son seçtiğin altyazı alanını kullanır.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Kumanda") {
                Toggle("Pil azalınca uyar", isOn: $prefs.batteryAlerts)
            }

            Section("Kupalar") {
                if psnSignedIn {
                    Button("PSN bağlantısını kaldır", role: .destructive) {
                        Task {
                            await TrophyStore.shared.signOut()
                            psnSignedIn = false
                        }
                    }
                } else {
                    Text("PSN hesabını Kupalar penceresinden bağlayabilirsin.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Kısayollar") {
                ForEach(HotKeys.Action.allCases, id: \.rawValue) { action in
                    LabeledContent(action.title, value: action.combo.label)
                }
            }

            Section {
                Toggle("Mac açılınca başlat", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 520)
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
        case .toggleLive: return "Canlı çeviri aç/kapat"
        case .translateArea: return "Bir alanı çevir"
        case .subtitleLog: return "Altyazı geçmişi"
        case .trophies: return "Kupalar"
        }
    }
}
