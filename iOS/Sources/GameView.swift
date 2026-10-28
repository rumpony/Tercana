import SwiftUI

struct GameView: View {
    let game: TrophyGame
    @State private var selected: Trophy?
    @Bindable private var store = TrophyStore.shared

    private var groups: [String] {
        var seen: [String] = []
        for trophy in store.trophies where !seen.contains(trophy.groupId ?? "default") { seen.append(trophy.groupId ?? "default") }
        return seen
    }

    private var loaded: Bool { store.selectedGame?.id == game.id && !store.trophies.isEmpty }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Artwork(url: game.iconURL, size: 72)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(game.platform).font(.caption).foregroundStyle(.secondary)
                        ProgressView(value: Double(game.progress), total: 100)
                        GradeCounts(counts: game.earnedTrophies, defined: game.definedTrophies)
                    }
                }
                if loaded, let days = Insights.platinumETA(store.trophies) {
                    Label(M.platinumETA(days), systemImage: "hourglass").font(.footnote)
                }
                Button(Local.shared.isHunting(game) ? M.stopHunting : M.startHunting,
                       systemImage: "scope") { Local.shared.toggleHunting(game) }
                    .font(.footnote)
                if let stats = store.gameStats, loaded {
                    Text(S.spanDays(max(1, Calendar.current.dateComponents([.day], from: stats.first, to: stats.last).day ?? 0)))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Menu(S.guides) {
                    ForEach(GuideLinks.forGame(game.name)) { Link($0.title, destination: $0.url) }
                }
            }
            Section {
                Picker("", selection: $store.filter) {
                    ForEach(TrophyStore.Filter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                if !loaded { ProgressView().frame(maxWidth: .infinity) }
            }
            if loaded {
                ForEach(groups, id: \.self) { group in
                    Section(groups.count > 1 ? (group == "default" ? M.baseGame : M.dlc(group)) : "") {
                        ForEach(store.visibleTrophies.filter { ($0.groupId ?? "default") == group }) { trophy in
                            Button { selected = trophy } label: {
                                TrophyRow(trophy: trophy, subtitle: store.showTranslations ? (store.translatedDetails[trophy.id] ?? trophy.detail) : trophy.detail,
                                          markedDone: Local.shared.isDone(trophy, in: game))
                            }
                            .tint(.primary)
                        }
                    }
                }
            }
        }
        .onBackdrop()
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu {
                Picker(S.order, selection: $store.order) {
                    ForEach(TrophyStore.Order.allCases) { Text($0.title).tag($0) }
                }
                Picker(S.rarity, selection: $store.rarityFilter) {
                    Text(S.anyRarity).tag(TrophyRarity?.none)
                    ForEach(TrophyRarity.allCases) { Text($0.title).tag(TrophyRarity?.some($0)) }
                }
                Toggle(S.translateDescriptions, isOn: $store.showTranslations)
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }
        .task(id: game.id) { await store.open(.game(game.id)) }
        .refreshable { await store.open(.game(game.id)) }
        .sheet(item: $selected) { TrophySheet(trophy: $0, game: game) }
    }
}

struct TrophyRow: View {
    let trophy: Trophy
    let subtitle: String
    var markedDone = false

    var body: some View {
        HStack(spacing: 12) {
            Artwork(url: trophy.iconURL, size: 44)
                .opacity(trophy.earned ? 1 : 0.45)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle().fill(trophy.grade.color).frame(width: 8, height: 8)
                    Text(trophy.name).font(.subheadline.weight(.medium)).lineLimit(1)
                }
                Text(trophy.hidden && !trophy.earned ? S.hiddenTrophy : subtitle)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                if let rate = trophy.earnedRate {
                    Text(S.percent(rate / 100, digits: 1)).font(.caption).monospacedDigit()
                }
                if trophy.earned {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Style.glow).font(.caption)
                } else if markedDone {
                    Image(systemName: "checkmark.circle").foregroundStyle(.tint).font(.caption)
                } else if let progress = trophy.progress, let target = trophy.progressTarget {
                    Text("\(progress)/\(target)").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct TrophySheet: View {
    let trophy: Trophy
    let game: TrophyGame
    @State private var note = ""
    @State private var revealed = false
    @Environment(\.dismiss) private var dismiss
    private var targets: TrophyTargets { .shared }
    private var showcase: TrophyShowcase { .shared }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        Artwork(url: trophy.iconURL, size: 96)
                        Text(trophy.name).font(.title3.bold()).multilineTextAlignment(.center)
                        if trophy.hidden && !trophy.earned && !revealed {
                            Button(S.revealSpoiler) { revealed = true }.font(.footnote)
                        } else {
                            Text(TrophyStore.shared.translatedDetails[trophy.id] ?? trophy.detail)
                                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        HStack(spacing: 16) {
                            Label(trophy.grade.label, systemImage: "trophy.fill").foregroundStyle(trophy.grade.color)
                            if let rarity = trophy.rarity { Text(rarity.title) }
                            if let rate = trophy.earnedRate { Text(S.earnedBy(rate)) }
                        }
                        .font(.caption)
                        if let date = trophy.earnedDate {
                            Text(date.shown(time: true)).font(.caption).foregroundStyle(Style.glow)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                Section {
                    if trophy.earned {
                        Button(showcase.contains(trophy, in: game) ? S.removeFromShowcase : S.addToShowcase) {
                            showcase.toggle(trophy, in: game)
                        }
                    } else {
                        Button(Local.shared.isDone(trophy, in: game) ? M.unmarkDone : M.markDone) {
                            Local.shared.toggleDone(trophy, in: game)
                        }
                        Button(targets.isPinned(trophy, in: game) ? S.unpinTarget : S.pinTarget) {
                            targets.toggle(trophy, in: game)
                        }
                        if targets.isPinned(trophy, in: game) {
                            TextField(S.notePlaceholder, text: $note, axis: .vertical)
                                .onChange(of: note) { targets.setNote(note, for: trophy, in: game) }
                        }
                    }
                }
                Section(S.howToGet) {
                    Link(S.searchYouTube, destination: GuideLinks.forTrophy(trophy.name, game: game.name))
                    Link(S.searchWebGuide, destination: GuideLinks.webSearch(trophy.name, game: game.name))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button(S.close) { dismiss() } }
            .onAppear { note = targets.note(for: trophy, in: game) }
        }
        .presentationDetents([.medium, .large])
    }
}
