import AppKit
import SwiftUI

struct TrophiesView: View {
    @State private var store = TrophyStore.shared

    var body: some View {
        Group {
            if store.signedIn {
                NavigationSplitView {
                    GameList(store: store)
                        .navigationSplitViewColumnWidth(min: 260, ideal: 300)
                } detail: {
                    if let game = store.selectedGame {
                        GameTrophies(store: store, game: game)
                    } else {
                        ContentUnavailableView(S.pickAGame, systemImage: "trophy")
                    }
                }
            } else {
                SignInView(store: store)
            }
        }
        .frame(minWidth: 820, minHeight: 540)
        .task { await store.load() }
    }
}

// MARK: - Sign in

private struct SignInView: View {
    let store: TrophyStore
    @State private var token = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(S.connectPSN, systemImage: "trophy.fill")
                .font(.title2.bold())
            Text(S.connectIntro)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                step(1, S.connectStep1)
                HStack {
                    step(2, S.connectStep2)
                    Button(S.openPage) { NSWorkspace.shared.open(PSNClient.sessionTokenURL) }
                }
                step(3, S.connectStep3)
            }
            HStack {
                SecureField(S.tokenPlaceholder, text: $token)
                    .textFieldStyle(.roundedBorder)
                Button(S.connect) {
                    let value = extract(token)
                    Task { await store.signIn(sessionToken: value) }
                }
                .disabled(token.isEmpty || store.loading)
                .keyboardShortcut(.defaultAction)
            }
            if store.loading { ProgressView().controlSize(.small) }
            if let problem = store.problem {
                Text(problem).foregroundStyle(.red)
            }
            Text(S.unofficialNote)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: 560)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number)").font(.headline).foregroundStyle(.tint)
            Text(text)
        }
    }

    /// Accepts either the bare token or the whole JSON the page shows.
    private func extract(_ input: String) -> String {
        if let range = input.range(of: #"[A-Za-z0-9]{64}"#, options: .regularExpression) {
            return String(input[range])
        }
        return input.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Games

private struct GameList: View {
    @Bindable var store: TrophyStore

    var body: some View {
        List(selection: Binding(get: { store.selectedGameID },
                                set: { id in Task { await store.select(id) } })) {
            if let playing = store.nowPlaying {
                Section(S.nowPlaying) {
                    Button {
                        Task { await store.showNowPlaying() }
                    } label: {
                        Label(playing, systemImage: "gamecontroller.fill")
                    }
                    .buttonStyle(.plain)
                }
            }
            Section(S.gamesCount(store.games.count)) {
                ForEach(store.visibleGames) { game in
                    GameRow(game: game).tag(game.id)
                }
            }
        }
        .searchable(text: $store.searchText, placement: .sidebar, prompt: S.searchGames)
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await store.load() }
                } label: {
                    Label(S.refresh, systemImage: "arrow.clockwise")
                }
                .disabled(store.loading)
            }
        }
    }
}

private struct GameRow: View {
    let game: TrophyGame

    var body: some View {
        HStack(spacing: 10) {
            AsyncImage(url: game.iconURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 3) {
                Text(game.name).lineLimit(1)
                ProgressView(value: Double(game.progress), total: 100)
                    .tint(game.progress == 100 ? .yellow : .accentColor)
                HStack(spacing: 6) {
                    Text(S.percent(Double(game.progress) / 100))
                    if game.platinumEarned { Text(S.platinumEarned).foregroundStyle(.yellow) }
                    Text(game.platform).foregroundStyle(.tertiary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Trophies of a game

private struct GameTrophies: View {
    @Bindable var store: TrophyStore
    let game: TrophyGame
    @State private var revealed: Set<Int> = []

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.loading && store.trophies.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.visibleTrophies) { trophy in
                    TrophyRow(trophy: trophy, game: game.name,
                              translation: store.showTranslations ? store.translatedDetails[trophy.id] : nil,
                              revealed: revealed.contains(trophy.id)) {
                        revealed.insert(trophy.id)
                    }
                }
            }
            if let problem = store.problem {
                Text(problem).font(.callout).foregroundStyle(.red).padding(8)
            }
        }
        .navigationTitle(game.name)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                counts(game.earnedTrophies, of: game.definedTrophies)
                Spacer()
                Menu {
                    ForEach(GuideLinks.forGame(game.name)) { link in
                        Button(link.title) { NSWorkspace.shared.open(link.url) }
                    }
                } label: {
                    Label(S.guides, systemImage: "book")
                }
                .fixedSize()
            }
            HStack {
                Picker("", selection: $store.filter) {
                    ForEach(TrophyStore.Filter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                Picker(S.order, selection: $store.order) {
                    ForEach(TrophyStore.Order.allCases) { Text($0.title).tag($0) }
                }
                .fixedSize()
                Spacer()
                Toggle(S.translateDescriptions, isOn: $store.showTranslations)
            }
        }
        .padding(14)
    }

    private func counts(_ earned: TrophyCounts, of defined: TrophyCounts) -> some View {
        HStack(spacing: 12) {
            if defined.platinum > 0 { badge(.platinum, earned.platinum, defined.platinum) }
            badge(.gold, earned.gold, defined.gold)
            badge(.silver, earned.silver, defined.silver)
            badge(.bronze, earned.bronze, defined.bronze)
        }
    }

    private func badge(_ grade: TrophyGrade, _ earned: Int, _ total: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "trophy.fill").foregroundStyle(grade.color)
            Text("\(earned)/\(total)").monospacedDigit()
        }
        .help(grade.label)
    }
}

private struct TrophyRow: View {
    let trophy: Trophy
    let game: String
    let translation: String?
    let revealed: Bool
    let onReveal: () -> Void

    private var concealed: Bool { trophy.hidden && !trophy.earned && !revealed }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: trophy.iconURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .saturation(trophy.earned ? 1 : 0)
            .opacity(trophy.earned ? 1 : 0.7)
            .blur(radius: concealed ? 6 : 0)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill").foregroundStyle(trophy.grade.color).font(.caption)
                    Text(concealed ? S.hiddenTrophy : trophy.name).font(.headline)
                    if trophy.earned {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    }
                }
                if concealed {
                    Button(S.revealSpoiler, action: onReveal)
                        .buttonStyle(.link)
                        .font(.callout)
                } else {
                    Text(translation ?? trophy.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                HStack(spacing: 10) {
                    if let rate = trophy.earnedRate {
                        Text(S.earnedBy(rate))
                            .foregroundStyle(rate < 5 ? .orange : .secondary)
                    }
                    if let progress = trophy.progress, let target = trophy.progressTarget, !trophy.earned {
                        Text(S.progress(progress, target))
                    }
                    if let date = trophy.earnedDate {
                        Text(date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(S.locale)))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if !trophy.earned && !concealed {
                Menu {
                    Button(S.searchYouTube) { NSWorkspace.shared.open(GuideLinks.forTrophy(trophy.name, game: game)) }
                    Button(S.searchWebGuide) { NSWorkspace.shared.open(GuideLinks.webSearch(trophy.name, game: game)) }
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(S.howToGet)
            }
        }
        .padding(.vertical, 4)
    }
}

extension TrophyGrade {
    var color: Color {
        switch self {
        case .bronze: return Color(red: 0.80, green: 0.50, blue: 0.25)
        case .silver: return Color(white: 0.75)
        case .gold: return Color(red: 0.95, green: 0.78, blue: 0.25)
        case .platinum: return Color(red: 0.62, green: 0.78, blue: 0.95)
        }
    }
}
