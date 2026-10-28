import SwiftUI

@main
struct TercanaMobileApp: App {
    @AppStorage(AppLanguage.defaultsKey) private var language = AppLanguage.system.rawValue
    @State private var tab = Demo.startTab
    private var store: TrophyStore { .shared }

    init() {
        if Demo.isOn { Demo.load() }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if store.signedIn {
                    TabView(selection: $tab) {
                        Tab(M.profileTab, systemImage: "person", value: 0) { ProfileView() }
                        Tab(M.gamesTab, systemImage: "gamecontroller", value: 1) { GamesView() }
                        Tab(M.targetsTab, systemImage: "pin", value: 2) { TargetsView() }
                        Tab(M.statsTab, systemImage: "chart.bar", value: 3) { StatsView() }
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
