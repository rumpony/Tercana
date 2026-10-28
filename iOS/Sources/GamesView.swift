import SwiftUI

struct GamesView: View {
    enum Scope: Hashable { case all, close, plats }
    @State private var scope = Scope.all
    @State private var search = ""
    private var store: TrophyStore { .shared }

    private var games: [TrophyGame] {
        let list: [TrophyGame]
        switch scope {
        case .all: list = store.games
        case .close: list = store.closestGames
        case .plats: list = store.platinumGames
        }
        guard !search.isEmpty else { return list }
        return list.filter { $0.name.localizedCaseInsensitiveContains(search) }
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
