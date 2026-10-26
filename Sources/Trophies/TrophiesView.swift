import AppKit
import SwiftUI

struct TrophiesView: View {
    @State private var store = TrophyStore.shared

    var body: some View {
        Group {
            if store.signedIn {
                // A plain two-column layout: NavigationSplitView inside a hand-made NSWindow has no
                // toolbar to host its search field, which pushed the sidebar content around.
                HStack(spacing: 0) {
                    Sidebar(store: store)
                        .frame(width: 290)
                    Divider()
                    detail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                SignInView(store: store)
            }
        }
        .frame(minWidth: 1040, minHeight: 600)
        .task { await store.load() }
    }

    @ViewBuilder
    private var detail: some View {
        switch store.page {
        case .profile: ProfilePage(store: store)
        case .stats: StatsPage(store: store)
        case .closest: GameGridPage(store: store, title: S.closestToFinish, empty: S.closestToFinish, games: store.closestGames)
        case .recent: RecentPage(store: store)
        case .platinums: GameGridPage(store: store, title: S.platinumCabinet, empty: S.noPlatinums, games: store.platinumGames)
        case .targets: TargetsPage(store: store)
        case .game:
            if let game = store.selectedGame {
                GameTrophies(store: store, game: game)
            } else {
                ContentUnavailableView(S.pickAGame, systemImage: "trophy")
            }
        }
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @Bindable var store: TrophyStore
    private let targets = TrophyTargets.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(S.searchGames, text: $store.searchText)
                        .textFieldStyle(.plain)
                    if !store.searchText.isEmpty {
                        Button {
                            store.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 7))
                if store.loading {
                    ProgressView().controlSize(.small).frame(width: 16)
                } else {
                    Button {
                        Task { await store.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help(S.refresh)
                }
            }
            .padding(10)
            list
            Divider()
            HStack {
                Button(role: .destructive) {
                    Task { await store.signOut() }
                } label: {
                    Label(S.signOutPSN, systemImage: "rectangle.portrait.and.arrow.right")
                }
                .buttonStyle(.borderless)
                .font(.callout)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private var list: some View {
        List(selection: Binding(get: { store.page }, set: { page in
            if let page { Task { await store.open(page) } }
        })) {
            Section(S.overview) {
                Label(S.profile, systemImage: "person.crop.circle").tag(TrophyStore.Page.profile)
                Label(S.statistics, systemImage: "chart.bar.xaxis").tag(TrophyStore.Page.stats)
                Label(S.closestToFinish, systemImage: "flag.checkered").tag(TrophyStore.Page.closest)
                Label(S.recentTrophies, systemImage: "clock").tag(TrophyStore.Page.recent)
                Label(S.platinumCabinet, systemImage: "trophy.fill").tag(TrophyStore.Page.platinums)
                Label(S.myTargets, systemImage: "pin")
                    .badge(targets.items.count)
                    .tag(TrophyStore.Page.targets)
            }
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
                    GameRow(game: game).tag(TrophyStore.Page.game(game.id))
                }
            }
        }
        .listStyle(.sidebar)
    }
}

private struct GameRow: View {
    let game: TrophyGame

    var body: some View {
        HStack(spacing: 10) {
            RemoteIcon(url: game.iconURL, size: 44)
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

// MARK: - Profile

private struct ProfilePage: View {
    let store: TrophyStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let profile = store.profile {
                    HStack(spacing: 18) {
                        ZStack {
                            Circle().stroke(.quaternary, lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: Double(profile.progress) / 100)
                                .stroke(.tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text(verbatim: "\(profile.level)").font(.system(size: 28, weight: .bold)).monospacedDigit()
                        }
                        .frame(width: 92, height: 92)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(S.trophyLevel(profile.level)).font(.title2.bold())
                            Text(S.toNextLevel(Double(profile.progress) / 100) + "  ·  " + S.gamesPlayed + ": \(store.games.count)")
                                .foregroundStyle(.secondary)
                            GradeCounts(counts: profile.earnedTrophies)
                        }
                    }
                }

                Fold(S.summary, key: "summary") {
                // Four equal tiles in one row; games played moves to the header line.
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    StatTile(title: S.totalTrophies,
                             value: "\(store.profile?.earnedTrophies.total ?? store.games.map(\.earnedTrophies.total).reduce(0, +))",
                             symbol: "trophy")
                    StatTile(title: S.platinums, value: "\(store.platinumGames.count)", symbol: "trophy.fill")
                    StatTile(title: S.completedGames, value: "\(store.completedCount)", symbol: "checkmark.seal")
                    StatTile(title: S.averageCompletion, value: S.percent(store.averageCompletion), symbol: "chart.pie")
                }
                }

                Fold(S.showcase, key: "showcase") { ShowcaseBlock(store: store) }

                if !store.closestGames.isEmpty {
                    Fold(S.closestToFinish, key: "profileClosest") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(store.closestGames.prefix(5)) { game in
                            Button {
                                Task { await store.open(.game(game.id)) }
                            } label: {
                                GameRow(game: game).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    }
                }
                if let problem = store.problem {
                    Text(problem).foregroundStyle(.red)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(S.profile)
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol).font(.callout).foregroundStyle(.secondary)
                .lineLimit(1)
            Text(verbatim: value).font(.system(size: 26, weight: .semibold)).monospacedDigit()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct GradeCounts: View {
    let counts: TrophyCounts
    var total: TrophyCounts?

    var body: some View {
        HStack(spacing: 12) {
            if (total?.platinum ?? 1) > 0 { badge(.platinum, counts.platinum, total?.platinum) }
            badge(.gold, counts.gold, total?.gold)
            badge(.silver, counts.silver, total?.silver)
            badge(.bronze, counts.bronze, total?.bronze)
        }
    }

    private func badge(_ grade: TrophyGrade, _ earned: Int, _ of: Int?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "trophy.fill").foregroundStyle(grade.color)
            Text(verbatim: of.map { "\(earned)/\($0)" } ?? "\(earned)").monospacedDigit()
        }
        .help(grade.label)
    }
}

// MARK: - Game grids & lists

private struct GameGridPage: View {
    let store: TrophyStore
    let title: String
    let empty: String
    let games: [TrophyGame]

    var body: some View {
        Group {
            if games.isEmpty {
                ContentUnavailableView(empty, systemImage: "trophy")
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 18) {
                        ForEach(games) { game in
                            Button {
                                Task { await store.open(.game(game.id)) }
                            } label: {
                                VStack(spacing: 6) {
                                    RemoteIcon(url: game.iconURL, size: 120)
                                    // Fixed two-line height keeps every cell's bar on the same line.
                                    Text(game.name).font(.callout).lineLimit(2).multilineTextAlignment(.center)
                                        .frame(height: 38, alignment: .top)
                                    ProgressView(value: Double(game.progress), total: 100)
                                        .tint(game.progress == 100 ? .yellow : .accentColor)
                                    Text(S.percent(Double(game.progress) / 100)).font(.caption).foregroundStyle(.secondary)
                                }
                                .frame(width: 140)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle(title)
    }
}

private struct RecentPage: View {
    let store: TrophyStore

    var body: some View {
        Group {
            if store.recent.isEmpty {
                if store.loadingRecent {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(S.noRecent, systemImage: "clock")
                }
            } else {
                List(store.recent) { item in
                    Button {
                        Task { await store.open(.game(item.game.id)) }
                    } label: {
                        HStack(spacing: 12) {
                            RemoteIcon(url: item.trophy.iconURL, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trophy.fill").foregroundStyle(item.trophy.grade.color).font(.caption)
                                    Text(item.trophy.name).font(.headline)
                                }
                                Text(item.game.name).font(.callout).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                if let rarity = item.trophy.rarity { RarityBadge(rarity: rarity, rate: item.trophy.earnedRate) }
                                if let date = item.trophy.earnedDate {
                                    Text(date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(S.locale)))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(S.recentTrophies)
    }
}

private struct TargetsPage: View {
    let store: TrophyStore
    private let targets = TrophyTargets.shared

    private var groups: [(gameID: String, items: [TrophyTargets.Target])] {
        Dictionary(grouping: targets.sorted, by: \.gameID)
            .map { (gameID: $0.key, items: $0.value) }
            .sorted { $0.items[0].added > $1.items[0].added }
    }

    var body: some View {
        Group {
            if targets.items.isEmpty {
                ContentUnavailableView(S.noTargets, systemImage: "pin", description: Text(S.noTargetsHint))
            } else {
                List {
                    ForEach(groups, id: \.gameID) { group in
                        Section {
                            ForEach(group.items) { target in
                                TargetRow(target: target)
                            }
                        } header: {
                            HStack {
                                Text(group.items[0].gameName)
                                Spacer()
                                Button(S.openGame) { Task { await store.open(.game(group.gameID)) } }
                                    .buttonStyle(.link)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(S.myTargets)
    }
}

private struct TargetRow: View {
    let target: TrophyTargets.Target
    @State private var note = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: "pin.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(target.trophyName).font(.headline)
                TextField(S.notePlaceholder, text: $note)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.secondary)
                    .onChange(of: note) { TrophyTargets.shared.setNote(note, forKey: target.id) }
            }
            Spacer()
            Button {
                TrophyTargets.shared.remove(target)
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .help(S.unpinTarget)
        }
        .onAppear { note = target.note }
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
                    TrophyRow(trophy: trophy, game: game,
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
                GradeCounts(counts: game.earnedTrophies, total: game.definedTrophies)
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
            if let stats = store.gameStats {
                HStack(spacing: 18) {
                    stat(S.firstTrophy, Self.day(stats.first))
                    stat(S.latestTrophy, Self.day(stats.last))
                    stat(S.duration, S.spanDays(max(1, Calendar.current.dateComponents([.day], from: stats.first, to: stats.last).day ?? 0)))
                    if let rarest = stats.rarest {
                        stat(S.rarestEarned, rarest.name + (rarest.earnedRate.map { " · " + S.percent($0 / 100, digits: 1) } ?? ""))
                    }
                }
                .font(.caption)
            }
            // Two rows so nothing gets pushed out of narrow windows.
            HStack {
                Picker("", selection: $store.filter) {
                    ForEach(TrophyStore.Filter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 320)
                Spacer(minLength: 12)
                Toggle(S.translateDescriptions, isOn: $store.showTranslations)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            HStack(spacing: 12) {
                // The options name themselves ("Easiest first", "Any rarity"), so no side labels.
                Picker(S.order, selection: $store.order) {
                    ForEach(TrophyStore.Order.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                Picker(S.rarity, selection: $store.rarityFilter) {
                    Text(S.anyRarity).tag(TrophyRarity?.none)
                    ForEach(TrophyRarity.allCases) { Text($0.label).tag(TrophyRarity?.some($0)) }
                }
                .labelsHidden()
                .fixedSize()
                Spacer(minLength: 0)
            }
        }
        .padding(14)
    }

    private static func day(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(S.locale))
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).foregroundStyle(.secondary)
            Text(verbatim: value).lineLimit(1)
        }
    }
}

private struct TrophyRow: View {
    let trophy: Trophy
    let game: TrophyGame
    let translation: String?
    let revealed: Bool
    let onReveal: () -> Void
    private let targets = TrophyTargets.shared
    private let showcase = TrophyShowcase.shared
    @State private var note = ""

    private var concealed: Bool { trophy.hidden && !trophy.earned && !revealed }
    private var pinned: Bool { targets.isPinned(trophy, in: game) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RemoteIcon(url: trophy.iconURL, size: 48)
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
                    if let rarity = trophy.rarity { RarityBadge(rarity: rarity, rate: trophy.earnedRate) }
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
                    if let progress = trophy.progress, let target = trophy.progressTarget, !trophy.earned {
                        Text(S.progress(progress, target))
                    }
                    if let date = trophy.earnedDate {
                        Text(date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(S.locale)))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if pinned {
                    TextField(S.notePlaceholder, text: $note)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout)
                        .onChange(of: note) { targets.setNote(note, for: trophy, in: game) }
                }
            }
            Spacer()
            if trophy.earned {
                let shown = showcase.contains(trophy, in: game)
                Button {
                    showcase.toggle(trophy, in: game)
                } label: {
                    Image(systemName: shown ? "star.fill" : "star").foregroundStyle(shown ? .yellow : .secondary)
                }
                .buttonStyle(.borderless)
                .help(shown ? S.removeFromShowcase : S.addToShowcase)
            } else {
                VStack(spacing: 8) {
                    Button {
                        targets.toggle(trophy, in: game)
                    } label: {
                        Image(systemName: pinned ? "pin.fill" : "pin")
                            .foregroundStyle(pinned ? .orange : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(pinned ? S.unpinTarget : S.pinTarget)
                    if !concealed {
                        Menu {
                            Button(S.searchYouTube) { NSWorkspace.shared.open(GuideLinks.forTrophy(trophy.name, game: game.name)) }
                            Button(S.searchWebGuide) { NSWorkspace.shared.open(GuideLinks.webSearch(trophy.name, game: game.name)) }
                        } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .help(S.howToGet)
                    }
                }
                // Same width on every row so the pins line up, with or without the help menu.
                .frame(width: 44, alignment: .top)
            }
        }
        .padding(.vertical, 4)
        .onAppear { note = targets.note(for: trophy, in: game) }
    }
}

// MARK: - Shared bits

private struct RarityBadge: View {
    let rarity: TrophyRarity
    let rate: Double?

    var body: some View {
        Text(verbatim: rate.map { "\(rarity.label) · \(S.percent($0 / 100, digits: 1))" } ?? rarity.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(rarity.color.opacity(0.2), in: Capsule())
            .foregroundStyle(rarity.color)
    }
}

private struct RemoteIcon: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Color.gray.opacity(0.2)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size > 60 ? 10 : 6))
    }
}

// MARK: - Sign in

struct SignInView: View {
    let store: TrophyStore
    @State private var token = ""
    @State private var manual = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "trophy.circle.fill").font(.system(size: 54)).foregroundStyle(.tint)
            Text(S.connectPSN).font(.title2.bold())
            Text(S.connectIntroShort)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
            Button {
                PSNWebLogin.shared.begin(
                    onCode: { code in Task { await store.signIn(authorizationCode: code) } },
                    onToken: { token in Task { await store.signIn(sessionToken: token) } })
            } label: {
                Label(S.signInWithPlayStation, systemImage: "person.badge.key")
                    .frame(minWidth: 240)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.loading)
            if store.loading { ProgressView().controlSize(.small) }
            if let problem = store.problem {
                Text(problem).foregroundStyle(.red).multilineTextAlignment(.center).frame(maxWidth: 420)
            }
            DisclosureGroup(S.advancedManualToken, isExpanded: $manual) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(S.manualStep)
                        Button(S.openPage) { NSWorkspace.shared.open(PSNClient.sessionTokenURL) }
                    }
                    HStack {
                        SecureField(S.tokenPlaceholder, text: $token).textFieldStyle(.roundedBorder)
                        Button(S.connect) {
                            let value = extract(token)
                            Task { await store.signIn(sessionToken: value) }
                        }
                        .disabled(token.isEmpty || store.loading)
                    }
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: 460)
            .font(.callout)
            Text(S.unofficialNote)
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Accepts either the bare token or the whole JSON the page shows.
    private func extract(_ input: String) -> String {
        if let range = input.range(of: #"[A-Za-z0-9]{64}"#, options: .regularExpression) {
            return String(input[range])
        }
        return input.trimmingCharacters(in: .whitespacesAndNewlines)
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

extension TrophyRarity {
    var label: String {
        switch self {
        case .ultraRare: return S.ultraRare
        case .veryRare: return S.veryRare
        case .rare: return S.rare
        case .common: return S.common
        }
    }

    var color: Color {
        switch self {
        case .ultraRare: return .orange
        case .veryRare: return .purple
        case .rare: return .blue
        case .common: return .gray
        }
    }
}
