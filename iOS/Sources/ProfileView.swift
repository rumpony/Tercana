import SwiftUI

struct ProfileView: View {
    @State private var target: Int?
    @State private var showingAccount = false
    private var store: TrophyStore { .shared }
    private var showcase: TrophyShowcase { .shared }
    private var local: Local { .shared }
    private var memories: [Insights.Earned] { Insights.onThisDay(TrophyStats(TrophyLibrary.shared.entries).earned) }

    var body: some View {
        NavigationStack {
            List {
                if let profile = store.profile {
                    Section { header(profile) }
                    Section(M.levelPlanner) { planner(profile) }
                }
                Section {
                    LazyVGrid(columns: [GridItem(), GridItem()], spacing: 16) {
                        Figure(value: "\(store.games.count)", caption: S.gamesPlayed)
                        Figure(value: "\(store.platinumGames.count)", caption: S.platinums)
                        Figure(value: "\(store.completedCount)", caption: S.completedGames)
                        Figure(value: S.percent(store.averageCompletion), caption: S.averageCompletion)
                    }
                    .padding(.vertical, 4)
                }
                let hunted = local.hunting.compactMap { id in store.games.first { $0.id == id } }
                if !hunted.isEmpty {
                    Section(M.hunting) {
                        ForEach(hunted) { game in NavigationLink(value: game) { GameRow(game: game) } }
                    }
                }
                if !memories.isEmpty {
                    Section(M.onThisDay) {
                        ForEach(Array(memories.prefix(5).enumerated()), id: \.offset) { _, item in
                            TrophyRow(trophy: item.trophy, subtitle: "\(M.yearsAgo(Calendar.current.component(.year, from: Date()) - Calendar.current.component(.year, from: item.date))) · \(item.game.name)")
                        }
                    }
                }
                if !store.platinumGames.isEmpty {
                    Section {
                        NavigationLink(M.platinumWall + " (\(store.platinumGames.count))") { PlatinumWall(games: store.platinumGames) }
                    }
                }
                if !showcase.items.isEmpty {
                    Section(S.showcase) {
                        ForEach(showcase.items) { item in
                            TrophyRow(trophy: item.trophy, subtitle: item.gameName)
                        }
                    }
                }
                if !store.closestGames.isEmpty {
                    Section(S.closestToFinish) {
                        ForEach(store.closestGames.prefix(5)) { game in
                            NavigationLink(value: game) { GameRow(game: game) }
                        }
                    }
                }
            }
            .screen(S.profile)
            .navigationDestination(for: TrophyGame.self) { GameView(game: $0) }
            .refreshable { await store.load() }
            .toolbar {
                if let profile = store.profile {
                    let card = snapshot(ProfileCard(profile: profile, platinums: store.platinumGames, name: nil))
                    ShareLink(item: card, preview: SharePreview(M.shareCard, image: card))
                }
                Button { showingAccount = true } label: { Image(systemName: "person.crop.circle") }
            }
            .sheet(isPresented: $showingAccount) { AccountSheet() }
        }
    }

    private func header(_ profile: TrophyProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(S.trophyLevel(profile.level)).font(.title2.bold())
                Spacer()
                Text(S.percent(Double(profile.progress) / 100)).foregroundStyle(.secondary).monospacedDigit()
            }
            ProgressView(value: Double(profile.progress), total: 100)
            GradeCounts(counts: profile.earnedTrophies)
            Text("\(M.points): \(Level.points(profile.earnedTrophies).formatted())")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func planner(_ profile: TrophyProfile) -> some View {
        let goal = max(target ?? profile.level + 1, profile.level + 1)
        let needed = Level.pointsNeeded(from: profile.level, progress: profile.progress, to: goal)
        return VStack(alignment: .leading, spacing: 8) {
            Stepper(M.targetLevel(goal), value: Binding(get: { goal }, set: { target = $0 }),
                    in: (profile.level + 1)...999)
            Text(M.pointsLeft(needed)).font(.headline)
            Text(M.roughly(gold: Int((Double(needed) / 90).rounded(.up)),
                           bronze: Int((Double(needed) / 15).rounded(.up)),
                           plats: Int((Double(needed) / 300).rounded(.up))))
                .font(.footnote).foregroundStyle(.secondary)
            Text(M.points15).font(.caption2).foregroundStyle(.tertiary)
        }
    }
}

struct AccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLanguage.defaultsKey) private var language = AppLanguage.system.rawValue
    @AppStorage("accent") private var accent = 0
    private var library: TrophyLibrary { .shared }

    var body: some View {
        NavigationStack {
            Form {
                Picker(M.language, selection: $language) {
                    ForEach(AppLanguage.allCases) { Text($0.nativeName).tag($0.rawValue) }
                }
                Picker(M.theme, selection: $accent) {
                    ForEach(Theme.colors.indices, id: \.self) { i in
                        Image(systemName: "circle.fill").foregroundStyle(Theme.colors[i]).tag(i)
                    }
                }
                .pickerStyle(.navigationLink)
                Section {
                    ForEach(Notifier.Kind.allCases, id: \.self) { kind in NotifyToggle(kind: kind) }
                } header: {
                    Text(M.notifications)
                } footer: {
                    Text(M.notifyHint)
                }
                Section {
                    Button(M.syncLibrary) { library.sync(with: TrophyStore.shared.games) }
                        .disabled(library.syncing)
                    if let date = library.snapshot.syncedAt {
                        Text(S.lastSynced(date.shown(time: true)))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button(S.signOutPSN, role: .destructive) {
                        Task { await TrophyStore.shared.signOut(); dismiss() }
                    }
                }
            }
            .navigationTitle(M.account)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button(S.close) { dismiss() } }
        }
    }
}

private struct NotifyToggle: View {
    let kind: Notifier.Kind
    @AppStorage private var on: Bool

    init(kind: Notifier.Kind) {
        self.kind = kind
        _on = AppStorage(wrappedValue: false, kind.key)
    }

    var body: some View {
        Toggle(kind.title, isOn: $on)
            .onChange(of: on) { if on { Task { await Notifier.requestPermission(); Notifier.schedule() } } }
    }
}
