import SwiftUI

@main
struct TercanaMobileApp: App {
    @AppStorage(AppLanguage.defaultsKey) private var language = AppLanguage.system.rawValue
    private var store: TrophyStore { .shared }

    init() {
        if Demo.isOn { Demo.load() }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if store.signedIn {
                    TabView {
                        Tab(M.profileTab, systemImage: "person") { ProfileView() }
                        Tab(M.gamesTab, systemImage: "gamecontroller") { GamesView() }
                        Tab(M.targetsTab, systemImage: "pin") { TargetsView() }
                        Tab(M.statsTab, systemImage: "chart.bar") { StatsView() }
                    }
                    .task { await store.load() }
                } else {
                    SignInView()
                }
            }
            // Strings are computed, so the tree is rebuilt when the language changes.
            .id(language)
        }
    }
}
