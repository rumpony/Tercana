import Charts
import SwiftUI

/// Library-wide statistics. Every block folds away and remembers whether it was open.
struct StatsPage: View {
    let store: TrophyStore
    private let library = TrophyLibrary.shared

    var body: some View {
        let stats = TrophyStats(library.entries)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SyncCard(store: store)
                if stats.isEmpty {
                    ContentUnavailableView(S.statsNeedSync, systemImage: "chart.bar.xaxis",
                                           description: Text(S.statsNeedSyncHint))
                } else {
                    Fold(S.streaks, key: "streaks") { StreakBlock(stats: stats) }
                    Fold(S.milestones, key: "milestones") { MilestoneBlock(stats: stats, store: store) }
                    Fold(S.rarestTrophies, key: "rarest") { RarestBlock(stats: stats, store: store) }
                    Fold(S.fastestPlatinums, key: "fastest") { FastestBlock(stats: stats, store: store) }
                    Fold(S.lastTwelveMonths, key: "months") {
                        BarBlock(buckets: stats.byMonth(locale: S.locale), color: .accentColor)
                    }
                    Fold(S.byYear, key: "years") { BarBlock(buckets: stats.byYear(), color: .purple) }
                    Fold(S.byWeekday, key: "weekdays") {
                        BarBlock(buckets: stats.byWeekday(locale: S.locale), color: .teal)
                    }
                    Fold(S.byHour, key: "hours") { BarBlock(buckets: stats.byHour(), color: .orange) }
                    Fold(S.breakdown, key: "breakdown") { BreakdownBlock(stats: stats) }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(S.statistics)
    }
}

/// A titled block that folds away; its open/closed state survives restarts.
struct Fold<Content: View>: View {
    let title: String
    @AppStorage private var open: Bool
    @ViewBuilder let content: () -> Content

    init(_ title: String, key: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self._open = AppStorage(wrappedValue: true, "fold.\(key)")
        self.content = content
    }

    var body: some View {
        DisclosureGroup(isExpanded: $open) {
            content()
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(title).font(.headline)
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Sync

struct SyncCard: View {
    let store: TrophyStore
    private let library = TrophyLibrary.shared

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath").font(.title2).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                if library.syncing {
                    Text(S.syncing(library.syncDone, library.syncTotal)).font(.headline)
                    ProgressView(value: Double(library.syncDone), total: Double(max(library.syncTotal, 1)))
                } else if let date = library.snapshot.syncedAt {
                    Text(S.lastSynced(date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(S.locale))))
                        .font(.headline)
                    Text(S.syncExplain).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(S.fullSyncTitle).font(.headline)
                    Text(S.fullSyncExplain(store.games.filter { $0.earnedTrophies.total > 0 }.count))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let problem = library.syncProblem {
                    Text(problem).font(.caption).foregroundStyle(.red)
                }
            }
            Spacer()
            if library.syncing {
                Button(S.stop) { library.cancelSync() }
            } else {
                Button(library.hasData ? S.syncNow : S.startFullSync) { library.sync(with: store.games) }
                    .disabled(store.games.isEmpty)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Blocks

private struct StreakBlock: View {
    let stats: TrophyStats

    var body: some View {
        let streaks = stats.streaks()
        // A grid wraps on narrow windows instead of pushing the page wider than the window.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), alignment: .leading)], alignment: .leading, spacing: 12) {
            figure(S.longestStreak, S.spanDays(streaks.longest))
            figure(S.currentStreak, S.spanDays(streaks.current))
            if let busiest = stats.busiestDay {
                figure(S.busiestDay, "\(busiest.date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(S.locale))) · \(S.trophyCount(busiest.count))")
            }
            figure(S.totalTrophies, "\(stats.earned.count)")
        }
    }

    private func figure(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: value).font(.title3.weight(.semibold)).monospacedDigit()
        }
    }
}

private struct MilestoneBlock: View {
    let stats: TrophyStats
    let store: TrophyStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(stats.milestones()) { moment in
                TrophyLine(title: moment.title, trophy: moment.trophy, game: moment.game, store: store)
            }
        }
    }
}

private struct RarestBlock: View {
    let stats: TrophyStats
    let store: TrophyStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(stats.rarest().enumerated()), id: \.offset) { index, item in
                TrophyLine(title: "#\(index + 1)", trophy: item.trophy, game: item.game, store: store)
            }
        }
    }
}

private struct FastestBlock: View {
    let stats: TrophyStats
    let store: TrophyStore

    var body: some View {
        if stats.platinums.isEmpty {
            Text(S.noPlatinums).foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(stats.fastestPlatinums()) { plat in
                    Button {
                        Task { await store.open(.game(plat.game.id)) }
                    } label: {
                        HStack {
                            Image(systemName: "trophy.fill").foregroundStyle(TrophyGrade.platinum.color)
                            Text(plat.game.name).lineLimit(1)
                            Spacer()
                            Text(Duration.seconds(plat.duration).formatted(.units(allowed: [.days, .hours, .minutes],
                                                                                  width: .abbreviated,
                                                                                  maximumUnitCount: 2)
                                .locale(S.locale)))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct BarBlock: View {
    let buckets: [TrophyStats.Bucket]
    let color: Color

    var body: some View {
        Chart(buckets) { bucket in
            BarMark(x: .value("", bucket.label), y: .value("", bucket.count))
                .foregroundStyle(color.gradient)
                .annotation(position: .top) {
                    if bucket.count > 0 {
                        Text(verbatim: "\(bucket.count)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
        }
        .chartXScale(domain: buckets.sorted { $0.order < $1.order }.map(\.label))
        // Charts ask for room for every axis label; let them shrink to the page instead.
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: 170)
    }
}

private struct BreakdownBlock: View {
    let stats: TrophyStats

    var body: some View {
        let grades = stats.byGrade()
        let rarities = stats.byRarity()
        HStack(alignment: .top, spacing: 40) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach([TrophyGrade.platinum, .gold, .silver, .bronze], id: \.self) { grade in
                    HStack {
                        Image(systemName: "trophy.fill").foregroundStyle(grade.color)
                        Text(grade.label)
                        Spacer(minLength: 20)
                        Text(verbatim: "\(grades[grade] ?? 0)").monospacedDigit()
                    }
                }
            }
            .frame(maxWidth: 220)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(TrophyRarity.allCases) { rarity in
                    HStack {
                        Circle().fill(rarity.color).frame(width: 9, height: 9)
                        Text(rarity.label)
                        Spacer(minLength: 20)
                        Text(verbatim: "\(rarities[rarity] ?? 0)").monospacedDigit()
                    }
                }
            }
            .frame(maxWidth: 220)
        }
    }
}

/// One trophy with its game, opening the game when clicked.
struct TrophyLine: View {
    let title: String
    let trophy: Trophy
    let game: TrophyGame
    let store: TrophyStore

    var body: some View {
        Button {
            Task { await store.open(.game(game.id)) }
        } label: {
            HStack(spacing: 10) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 130, alignment: .leading)
                AsyncImage(url: trophy.iconURL) { $0.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.2) }
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Image(systemName: "trophy.fill").foregroundStyle(trophy.grade.color).font(.caption2)
                        Text(trophy.name).lineLimit(1)
                    }
                    Text(game.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if let rate = trophy.earnedRate {
                    Text(S.percent(rate / 100, digits: 1)).font(.caption).monospacedDigit()
                        .foregroundStyle((trophy.rarity ?? .common).color)
                }
                if let date = trophy.earnedDate {
                    Text(date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(S.locale)))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Trophies the player chose to show off, on the profile page.
struct ShowcaseBlock: View {
    let store: TrophyStore
    private let showcase = TrophyShowcase.shared

    var body: some View {
        if showcase.items.isEmpty {
            Text(S.showcaseEmpty).foregroundStyle(.secondary)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
                ForEach(showcase.items) { item in
                    Button {
                        Task { await store.open(.game(item.gameID)) }
                    } label: {
                        VStack(spacing: 4) {
                            AsyncImage(url: item.trophy.iconURL) { $0.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.2) }
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "trophy.fill").foregroundStyle(item.trophy.grade.color)
                                        .padding(3).background(.black.opacity(0.6), in: Circle())
                                }
                            Text(item.trophy.name).font(.caption).lineLimit(2).multilineTextAlignment(.center)
                        }
                        .frame(width: 96)
                    }
                    .buttonStyle(.plain)
                    .help(item.gameName)
                }
            }
        }
    }
}
