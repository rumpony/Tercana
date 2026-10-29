import SwiftUI

struct FriendsView: View {
    @State private var friends: [PSNClient.Player] = []
    @State private var loading = false
    @State private var failed = false
    @State private var query = ""
    @State private var found: PSNClient.Player?
    @State private var searchProblem: String?
    @State private var showingBoard = true

    var body: some View {
        NavigationStack {
            GlassList {
                Picker("", selection: $showingBoard) {
                    Text(M.leaderboard).tag(true)
                    Text(M.friendsList).tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                if showingBoard && query.isEmpty {
                    LeaderboardView()
                } else {
                if let found {
                    Section { NavigationLink(value: found) { PlayerRow(player: found) } }
                }
                if let searchProblem { Text(searchProblem).foregroundStyle(.secondary) }
                Section {
                    ForEach(friends) { player in NavigationLink(value: player) { PlayerRow(player: player) } }
                }
                }
            }
            .overlay {
                if loading && friends.isEmpty { ProgressView() }
                else if !showingBoard && friends.isEmpty && found == nil && searchProblem == nil { ContentUnavailableView(M.noFriends, systemImage: "person.2") }
            }
            .onBackdrop()
            .screen(M.friendsTab)
            .searchable(text: $query, prompt: M.searchPlayer)
            .onSubmit(of: .search) { Task { await search() } }
            .navigationDestination(for: PSNClient.Player.self) { PlayerView(player: $0) }
            .navigationDestination(for: TrophyGame.self) { GameView(game: $0) }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        guard !Demo.isOn else { return }
        loading = true
        defer { loading = false }
        do {
            friends = try await PSNClient.shared.friends()
            failed = friends.isEmpty
        } catch {
            failed = true
        }
    }

    private func search() async {
        found = nil
        searchProblem = nil
        guard !query.isEmpty else { return }
        do { found = try await PSNClient.shared.player(named: query) } catch { searchProblem = M.notFound }
    }
}

struct PlayerRow: View {
    let player: PSNClient.Player

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: player.avatarURL) { $0.resizable() } placeholder: { Color.secondary.opacity(0.15) }
                .frame(width: 40, height: 40).clipShape(Circle())
            Text(player.onlineId).font(.body.weight(.medium))
        }
    }
}

/// Another player's summary and the games you both have, side by side.
struct PlayerView: View {
    let player: PSNClient.Player
    @State private var profile: TrophyProfile?
    @State private var games: [TrophyGame] = []
    @State private var hidden = false
    private var store: TrophyStore { .shared }

    private var common: [(mine: TrophyGame, theirs: TrophyGame)] {
        let mine = Dictionary(store.games.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return games.compactMap { theirs in mine[theirs.id].map { (mine: $0, theirs: theirs) } }
    }

    var body: some View {
        GlassList {
            if hidden {
                Text(M.privateProfile).foregroundStyle(.secondary)
            }
            if let profile {
                Section {
                    compareRow(M.level,
                               store.profile?.level, profile.level)
                    ForEach(TrophyGrade.allCases.reversed(), id: \.self) { grade in
                        compareRow(grade.label, store.profile?.earnedTrophies.value(grade), profile.earnedTrophies.value(grade))
                    }
                    compareRow(M.points, store.profile.map { Level.points($0.earnedTrophies) }, Level.points(profile.earnedTrophies))
                } header: {
                    HStack { Text(M.compare); Spacer(); Text(M.you); Text("·"); Text(player.onlineId) }
                }
            }
            if !common.isEmpty {
                Section(M.commonGames + " (\(common.count))") {
                    ForEach(common, id: \.mine.id) { pair in
                        NavigationLink(value: pair.mine) {
                            HStack(spacing: 12) {
                                Artwork(url: pair.mine.iconURL, size: 40)
                                Text(pair.mine.name).font(.subheadline).lineLimit(2)
                                Spacer()
                                Text("\(pair.mine.progress)%").monospacedDigit()
                                    .foregroundStyle(pair.mine.progress >= pair.theirs.progress ? Style.glow : .secondary)
                                Text("\(pair.theirs.progress)%").monospacedDigit()
                                    .foregroundStyle(pair.theirs.progress > pair.mine.progress ? Style.glow : .secondary)
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            if !games.isEmpty {
                Section(S.gamesCount(games.count)) {
                    ForEach(games.prefix(50)) { game in GameRow(game: game) }
                }
            }
        }
        .navigationTitle(player.onlineId)
        .inlineTitle()
        .task {
            do {
                profile = try await PSNClient.shared.profile(user: player.accountId)
                games = try await PSNClient.shared.games(user: player.accountId)
            } catch {
                hidden = true
            }
        }
    }

    private func compareRow(_ title: String, _ mine: Int?, _ theirs: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(mine.map { $0.formatted() } ?? "–").monospacedDigit()
                .foregroundStyle((mine ?? 0) >= theirs ? Style.glow : .secondary)
            Text("·").foregroundStyle(.tertiary)
            Text(theirs.formatted()).monospacedDigit()
                .foregroundStyle(theirs > (mine ?? 0) ? Style.glow : .secondary)
        }
    }
}
