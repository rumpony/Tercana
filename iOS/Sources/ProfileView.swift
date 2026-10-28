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
            ScrollView {
                VStack(spacing: 16) {
                    if let profile = store.profile {
                        hero(profile)
                        planner(profile)
                    }
                    quickActions
                    rail(M.hunting, local.hunting.compactMap { id in store.games.first { $0.id == id } })
                    rail(S.closestToFinish, Array(store.closestGames.prefix(10)))
                    if !memories.isEmpty {
                        SectionTitle(text: M.onThisDay)
                        VStack(spacing: 12) {
                            ForEach(Array(memories.prefix(3).enumerated()), id: \.offset) { _, item in
                                TrophyRow(trophy: item.trophy, subtitle: "\(M.yearsAgo(Calendar.current.component(.year, from: Date()) - Calendar.current.component(.year, from: item.date))) · \(item.game.name)")
                            }
                        }
                        .card()
                    }
                    if !showcase.items.isEmpty {
                        SectionTitle(text: S.showcase)
                        VStack(spacing: 12) {
                            ForEach(showcase.items) { TrophyRow(trophy: $0.trophy, subtitle: $0.gameName) }
                        }
                        .card()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .onBackdrop()
            .screen(S.profile)
            .navigationDestination(for: TrophyGame.self) { GameView(game: $0) }
            .refreshable { await store.load() }
            .toolbar {
                Button { showingAccount = true } label: { Image(systemName: "gearshape") }
            }
            .sheet(isPresented: $showingAccount) { AccountSheet() }
        }
    }

    private func hero(_ profile: TrophyProfile) -> some View {
        VStack(spacing: 20) {
            LevelRing(level: profile.level, progress: profile.progress, size: 168)
                .padding(.top, 4)
            HStack {
                stat(Level.points(profile.earnedTrophies).formatted(), M.points)
                stat("\(store.games.count)", S.gamesPlayed)
                stat(S.percent(store.averageCompletion), S.averageCompletion)
            }
            Divider().overlay(.white.opacity(0.1))
            HStack {
                ForEach(TrophyGrade.allCases.reversed(), id: \.self) {
                    GradeChip(grade: $0, count: profile.earnedTrophies.value($0))
                }
            }
        }
        .card(padding: 20)
    }

    private func stat(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold().monospacedDigit())
            Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            if let profile = store.profile {
                let card = snapshot(ProfileCard(profile: profile, platinums: store.platinumGames, name: nil))
                ShareLink(item: card, preview: SharePreview(M.shareCard, image: card)) {
                    action("square.and.arrow.up", M.share)
                }
            }
            NavigationLink { PlatinumWall(games: store.platinumGames) } label: {
                action("trophy", "\(store.platinumGames.count)")
            }
            NavigationLink { YearReview(earned: TrophyStats(TrophyLibrary.shared.entries).earned) } label: {
                action("calendar", M.yearReview)
            }
        }
        .tint(.primary)
    }

    private func action(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.caption.weight(.medium)).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 12)
    }

    @ViewBuilder
    private func rail(_ title: String, _ games: [TrophyGame]) -> some View {
        if !games.isEmpty {
            SectionTitle(text: title)
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(games) { game in
                        NavigationLink(value: game) { GameTile(game: game) }.tint(.primary)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .padding(.horizontal, -16)
        }
    }

    private func planner(_ profile: TrophyProfile) -> some View {
        let goal = max(target ?? profile.level + 1, profile.level + 1)
        let needed = Level.pointsNeeded(from: profile.level, progress: profile.progress, to: goal)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(M.levelPlanner, systemImage: "target").font(.subheadline.weight(.semibold))
                Spacer()
                Stepper(M.targetLevel(goal), value: Binding(get: { goal }, set: { target = $0 }),
                        in: (profile.level + 1)...999).labelsHidden()
            }
            Text("\(M.targetLevel(goal)) · \(M.pointsLeft(needed))").font(.headline)
            Text(M.roughly(gold: Int((Double(needed) / 90).rounded(.up)),
                           bronze: Int((Double(needed) / 15).rounded(.up)),
                           plats: Int((Double(needed) / 300).rounded(.up))))
                .font(.footnote).foregroundStyle(.secondary)
        }
        .card()
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
