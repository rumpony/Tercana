import SwiftUI

@main
struct TercanaMobileApp: App {
    @AppStorage(AppLanguage.defaultsKey) private var language = AppLanguage.system.rawValue
    @AppStorage("accent") private var accent = 0
    @Environment(\.scenePhase) private var phase
    @State private var tab = Demo.startTab
    private var store: TrophyStore { .shared }

    init() {
        if Demo.isOn { Demo.load() }
        Notifier.register()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if store.signedIn {
                    TabView(selection: $tab) {
                        Tab(M.profileTab, systemImage: "person", value: 0) { ProfileView() }
                        Tab(M.gamesTab, systemImage: "gamecontroller", value: 1) { GamesView() }
                        Tab(M.targetsTab, systemImage: "pin", value: 2) { TargetsView() }
                        Tab(M.friendsTab, systemImage: "person.2", value: 3) { FriendsView() }
                        Tab(M.statsTab, systemImage: "chart.bar", value: 4) { StatsView() }
                    }
                    .task {
                        await store.load()
                        Notifier.updateWidget(profile: store.profile, games: store.games)
                    }
                } else {
                    SignInView()
                }
            }
            .tint(Theme.colors[min(accent, Theme.colors.count - 1)])
            // Strings are computed, so the tree is rebuilt when the language changes.
            .id(language)
        }
        .onChange(of: phase) {
            switch phase {
            case .active: Task { await Notifier.check(notify: false) }
            case .background: Notifier.schedule()
            default: break
            }
        }
    }
}

enum Theme {
    static let colors: [Color] = [.accentColor, .blue, .indigo, .purple, .pink, .orange, .green]
}
