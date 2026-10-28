import SwiftUI

struct GamesView: View {
    enum Scope: Hashable { case all, close, plats }
    @State private var scope = Scope.all
    @State private var search = ""
    @State private var sort = Sort.recent
    @State private var platform = ""
    enum Sort: Hashable { case recent, progress, name }
    private var store: TrophyStore { .shared }

    private var games: [TrophyGame] {
        let list: [TrophyGame]
        switch scope {
        case .all: list = store.games
        case .close: list = store.closestGames
        case .plats: list = store.platinumGames
        }
        var result = list
        if !platform.isEmpty { result = result.filter { $0.platform.contains(platform) } }
        if !search.isEmpty { result = result.filter { $0.name.localizedCaseInsensitiveContains(search) } }
        switch sort {
        case .recent: return scope == .close ? result : result.sorted { ($0.lastUpdatedDateTime ?? "") > ($1.lastUpdatedDateTime ?? "") }
        case .progress: return result.sorted { $0.progress > $1.progress }
        case .name: return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("", selection: $scope) {
                    Text(M.all).tag(Scope.all)
                    Text(M.close).tag(Scope.close)
                    Text(M.plats).tag(Scope.plats)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                ForEach(games) { game in
                    NavigationLink(value: game) { GameRow(game: game) }
                }
            }
            .navigationTitle(M.gamesTab)
            .searchable(text: $search, prompt: S.searchGames)
            .navigationDestination(for: TrophyGame.self) { GameView(game: $0) }
            .refreshable { await store.load() }
            .toolbar {
                Menu {
                    Picker(M.sortBy, selection: $sort) {
                        Text(M.sortRecent).tag(Sort.recent)
                        Text(M.sortProgress).tag(Sort.progress)
                        Text(M.sortName).tag(Sort.name)
                    }
                    Picker(M.platform, selection: $platform) {
                        Text(M.allPlatforms).tag("")
                        ForEach(["PS5", "PS4", "PS3", "PSVITA", "PSPC"], id: \.self) { Text($0).tag($0) }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
            }
        }
    }
}

struct GameRow: View {
    let game: TrophyGame

    var body: some View {
        HStack(spacing: 12) {
            Artwork(url: game.iconURL, size: 52)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(game.name).font(.subheadline.weight(.medium)).lineLimit(1)
                    Spacer()
                    if Local.shared.isHunting(game) {
                        Image(systemName: "scope").foregroundStyle(.tint).font(.caption)
                    }
                    if game.platinumEarned {
                        Image(systemName: "trophy.fill").foregroundStyle(TrophyGrade.platinum.color).font(.caption)
                    }
                    Text("\(game.progress)%").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                ProgressView(value: Double(game.progress), total: 100).tint(game.progress == 100 ? .green : .accentColor)
                GradeCounts(counts: game.earnedTrophies, defined: game.definedTrophies)
            }
        }
        .padding(.vertical, 2)
    }
}
