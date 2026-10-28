import Charts
import SwiftUI

struct StatsView: View {
    private var library: TrophyLibrary { .shared }
    private var store: TrophyStore { .shared }

    var body: some View {
        NavigationStack {
            Group {
                if library.hasData {
                    content(TrophyStats(library.entries))
                } else {
                    syncPrompt
                }
            }
            .onBackdrop()
            .screen(M.statsTab)
            .navigationDestination(for: TrophyGame.self) { GameView(game: $0) }
        }
    }

    private var syncPrompt: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(S.statsNeedSync, systemImage: "chart.bar", description: Text(S.statsNeedSyncHint))
                .fixedSize(horizontal: false, vertical: true)
            if library.syncing {
                ProgressView(value: Double(library.syncDone), total: Double(max(library.syncTotal, 1)))
                    .padding(.horizontal, 40)
                Text(S.syncing(library.syncDone, library.syncTotal)).font(.footnote).foregroundStyle(.secondary)
            } else {
                Button(S.startFullSync) { library.sync(with: store.games) }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.games.isEmpty)
            }
            if let problem = library.syncProblem { Text(problem).font(.footnote).foregroundStyle(.red) }
        }
        .frame(maxHeight: .infinity)
    }

    private func content(_ stats: TrophyStats) -> some View {
        let streaks = stats.streaks()
        let locale = S.locale
        return GlassList {
            Section(S.summary) {
                LazyVGrid(columns: [GridItem(), GridItem()], spacing: 16) {
                    Figure(value: "\(stats.earned.count)", caption: S.totalTrophies)
                    Figure(value: "\(stats.platinums.count)", caption: S.platinums)
                    Figure(value: "\(streaks.longest)", caption: S.longestStreak)
                    Figure(value: "\(streaks.current)", caption: S.currentStreak)
                }
                .padding(.vertical, 4)
                if let day = stats.busiestDay {
                    LabeledContent(S.busiestDay, value: "\(day.date.shown()) · \(day.count)")
                        .font(.footnote)
                }
            }
            Section(M.heatmap) {
                Heatmap(counts: Insights.perDay(stats.earned))
                if let average = Insights.averageRarity(stats.earned) {
                    LabeledContent(M.averageRarity, value: S.percent(average / 100, digits: 1)).font(.footnote)
                }
            }
            Section {
                NavigationLink(M.yearReview) { YearStory(earned: stats.earned) }
                NavigationLink(M.nextUp) { NextUpView(items: Insights.nextUp(library.entries)) }
                NavigationLink(M.platinumWall) { PlatinumWall(games: store.platinumGames) }
            }
            Section(S.lastTwelveMonths) {
                Chart(stats.byMonth(locale: locale)) { bucket in
                    BarMark(x: .value("", bucket.label), y: .value("", bucket.count))
                        .foregroundStyle(Style.glow.gradient)
                }
                .frame(height: 160)
            }
            Section(S.breakdown) {
                let grades = stats.byGrade()
                ForEach(TrophyGrade.allCases, id: \.self) { grade in
                    LabeledContent {
                        Text("\(grades[grade] ?? 0)").monospacedDigit()
                    } label: {
                        Label { Text(grade.label) } icon: { Circle().fill(grade.color).frame(width: 10) }
                    }
                }
            }
            if !stats.fastestPlatinums().isEmpty {
                Section(S.fastestPlatinums) {
                    ForEach(stats.fastestPlatinums(limit: 5)) { plat in
                        LabeledContent(plat.game.name, value: Duration.seconds(plat.duration)
                            .formatted(.units(allowed: [.days, .hours], width: .abbreviated, maximumUnitCount: 2)))
                            .lineLimit(1)
                    }
                }
            }
            Section(S.rarestTrophies) {
                ForEach(stats.rarest(limit: 8), id: \.trophy.id) { item in
                    TrophyRow(trophy: item.trophy, subtitle: item.game.name)
                }
            }
            Section(S.milestones) {
                ForEach(stats.milestones()) { moment in
                    TrophyRow(trophy: moment.trophy, subtitle: "\(moment.title) · \(moment.game.name)")
                }
            }
            Section {
                Button(S.syncNow) { library.sync(with: store.games) }.disabled(library.syncing)
                if let date = library.snapshot.syncedAt {
                    Text(S.lastSynced(date.shown(time: true)))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }
}
