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
    @AppStorage("accent") private var accent = 0
    @Namespace private var tabs

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch router.tab {
                case .home: HomePage().transition(.opacity)
                case .history: SubtitleLogView().frame(maxWidth: 820).transition(.opacity)
                case .trophies: TrophiesView().transition(.opacity)
                case .settings: SettingsView().transition(.opacity)
                }
            }
            // Lists and forms sit on the window backdrop like the trophy screens.
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.18), value: router.tab)
        }
        // The tab bar lives in the window toolbar on every tab, so the title bar never changes height
        // when the trophy hub adds its own buttons there.
        .toolbar {
            ToolbarItem(placement: .principal) { tabBar }
        }
        .background(Style.backdrop.ignoresSafeArea())
        // One look for the whole window, the same as the phone app.
        .preferredColorScheme(.dark)
        .tint(Style.glow)
        .id(accent)
        .frame(minWidth: 1040, minHeight: 660)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { tab in
                let selected = router.tab == tab
                Button {
                    router.tab = tab
                } label: {
                    // Icon and text spelled out: a Label in the toolbar would drop its title.
                    HStack(spacing: 6) {
                        Image(systemName: tab.symbol)
                        Text(tab.title).lineLimit(1)
                    }
                        .font(.callout.weight(selected ? .semibold : .regular))
                        .foregroundStyle(selected ? .primary : .secondary)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background {
                            if selected {
                                Capsule().fill(Style.glow.opacity(0.25))
                                    .matchedGeometryEffect(id: "tab", in: tabs)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.white.opacity(0.06), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.06)))
        .animation(.spring(duration: 0.3), value: router.tab)
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
                Circle().fill(app.isLive ? Style.glow.opacity(0.22) : Color.white.opacity(0.06))
                    .frame(width: 132, height: 132)
                    .shadow(color: app.isLive ? Style.glow.opacity(0.6) : .clear, radius: 24)
                Circle().stroke(app.isLive ? Style.glow : Color.white.opacity(0.1), lineWidth: 3)
                    .frame(width: 132, height: 132)
                Image(systemName: app.isLive ? "captions.bubble.fill" : "captions.bubble")
                    .font(.system(size: 50))
                    .foregroundStyle(app.isLive ? Style.glow : .secondary)
                    .symbolEffect(.pulse, isActive: app.isLive)
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
                        .frame(width: 210)
                }
                .buttonStyle(.borderedProminent)
                .tint(app.isLive ? .red : Style.glow)
                .controlSize(.large)
                Button { app.translateArea() } label: {
                    Label(S.translateArea, systemImage: "viewfinder").frame(width: 210)
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
            .lineLimit(1)
            .frame(width: 210)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white.opacity(0.06), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.06)))
    }
}
