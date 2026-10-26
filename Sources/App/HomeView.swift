import SwiftUI

/// The single app window: a home page plus the other screens as tabs.
struct HomeView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case home, history, trophies, settings
        var id: String { rawValue }

        var title: String {
            switch self {
            case .home: return S.homeTab
            case .history: return S.subtitleLog
            case .trophies: return S.trophies
            case .settings: return S.settingsTab
            }
        }

        var symbol: String {
            switch self {
            case .home: return "house"
            case .history: return "text.bubble"
            case .trophies: return "trophy"
            case .settings: return "gearshape"
            }
        }
    }

    @Bindable var router: HomeRouter

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $router.tab) {
                ForEach(Tab.allCases) { tab in
                    Label(tab.title, systemImage: tab.symbol).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 560)
            .padding(.vertical, 10)
            Divider()
            ZStack {
                switch router.tab {
                case .home: HomePage().transition(.opacity)
                case .history: SubtitleLogView().transition(.opacity)
                case .trophies: TrophiesView().transition(.opacity)
                case .settings: SettingsView().transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.18), value: router.tab)
        }
        .frame(minWidth: 900, minHeight: 660)
    }
}

@MainActor
@Observable
final class HomeRouter {
    var tab: HomeView.Tab = .home
}

private struct HomePage: View {
    private let app = AppController.shared
    private let prefs = Preferences.shared
    private let controller = ControllerWatch.shared

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 10)
            ZStack {
                Circle().fill(app.isLive ? Color.green.opacity(0.18) : Color.secondary.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: app.isLive ? "captions.bubble.fill" : "captions.bubble")
                    .font(.system(size: 48))
                    .foregroundStyle(app.isLive ? .green : .secondary)
            }
            Text(app.isLive ? S.liveOn : S.liveOff).font(.title2.bold())
            HStack(spacing: 16) {
                chip("character.bubble", "\(S.languageName(prefs.sourceLanguage)) → \(S.languageName(prefs.targetLanguage))")
                chip("gamecontroller", controller.summary ?? S.noController)
            }
            HStack(spacing: 12) {
                Button {
                    app.toggleLive()
                } label: {
                    Label(app.isLive ? S.stopLive : S.startLive, systemImage: app.isLive ? "stop.fill" : "play.fill")
                        .frame(minWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .tint(app.isLive ? .red : .accentColor)
                .controlSize(.large)
                Button { app.translateArea() } label: {
                    Label(S.translateArea, systemImage: "viewfinder").frame(minWidth: 160)
                }
                .controlSize(.large)
            }
            Button(S.newLiveArea) { app.startLive(reselect: true) }
                .buttonStyle(.link)
            Spacer()
            HStack(spacing: 18) {
                ForEach(HotKeys.Action.allCases, id: \.rawValue) { action in
                    Text("\(action.combo.label)  \(action.title)").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: app.isLive)
    }

    private func chip(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.6), in: Capsule())
    }
}
