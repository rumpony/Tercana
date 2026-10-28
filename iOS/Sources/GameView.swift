import Network
import SwiftUI

struct GameView: View {
    let game: TrophyGame
    @State private var selected: Trophy?
    @State private var celebrating: Date?
    @Bindable private var store = TrophyStore.shared
    private var online: Bool { Connectivity.shared.online }

    /// Fresh list from PSN when it has loaded, otherwise the copy from the last library sync.
    private var trophies: [Trophy] {
        if loaded { return store.trophies }
        return TrophyLibrary.shared.snapshot.entries[game.id]?.trophies ?? []
    }

    private var visible: [Trophy] {
        if loaded { return store.visibleTrophies }
        switch store.filter {
        case .all: return trophies
        case .missing: return trophies.filter { !$0.earned }
        case .earned: return trophies.filter(\.earned)
        }
    }

    private var groups: [String] {
        var seen: [String] = []
        for trophy in trophies where !seen.contains(trophy.groupId ?? "default") { seen.append(trophy.groupId ?? "default") }
        return seen
    }

    private var loaded: Bool { store.selectedGame?.id == game.id && !store.trophies.isEmpty }

    var body: some View {
        GlassList {
            Section {
                header
                Picker("", selection: $store.filter) {
                    ForEach(TrophyStore.Filter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowSeparator(.hidden)

            if trophies.isEmpty {
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
            ForEach(groups, id: \.self) { group in
                Section(groups.count > 1 ? (group == "default" ? M.baseGame : M.dlc(group)) : "") {
                    ForEach(visible.filter { ($0.groupId ?? "default") == group }) { trophy in
                        Button { selected = trophy } label: {
                            TrophyRow(trophy: trophy,
                                      subtitle: store.showTranslations ? (store.translatedDetails[trophy.id] ?? trophy.detail) : trophy.detail,
                                      markedDone: !online && Local.shared.isDone(trophy, in: game))
                        }
                        .tint(.primary)
                        .trophyActions(trophy, in: game, canMark: !online)
                    }
                }
            }
        }
        .listSectionSpacing(.compact)
        .contentMargins(.horizontal, 16, for: .scrollContent)
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
                Image(systemName: "line.3.horizontal.decrease")
            }
        }
        .task(id: game.id) { await store.open(.game(game.id)) }
        .refreshable { await store.open(.game(game.id)) }
        .onChange(of: loaded, initial: true) {
            guard loaded else { return }
            // Online, PSN is the truth: hand marks for this game are dropped.
            Local.shared.clearMarks(for: game)
            celebrateIfNew()
        }
        .fullScreenCover(item: $celebrating) { PlatinumMoment(game: game, date: $0) }
        .sheet(item: $selected) { TrophySheet(trophy: $0, game: game, canMark: !online) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Artwork(url: game.iconURL, size: 76)
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                VStack(alignment: .leading, spacing: 6) {
                    Text(game.name).font(.headline).lineLimit(2)
                    Text(game.platform).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                LevelRing(level: game.progress, progress: game.progress, size: 56, showsPercent: false)
            }
            GradeCounts(counts: game.earnedTrophies, defined: game.definedTrophies).fixedSize()
            HStack(spacing: 8) {
                if let days = Insights.platinumETA(trophies) {
                    pill(M.platinumETA(days), "hourglass")
                } else if let stats = store.gameStats, loaded {
                    pill(S.spanDays(max(1, Calendar.current.dateComponents([.day], from: stats.first, to: stats.last).day ?? 0)), "calendar")
                }
                Spacer(minLength: 0)
                Button {
                    Local.shared.toggleHunting(game)
                    Haptic.tap()
                } label: {
                    Image(systemName: Local.shared.isHunting(game) ? "scope" : "plus.viewfinder")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.glass)
                .tint(Local.shared.isHunting(game) ? Style.glow : nil)
                .accessibilityLabel(Local.shared.isHunting(game) ? M.stopHunting : M.startHunting)
                Menu {
                    ForEach(GuideLinks.forGame(game.name)) { Link($0.title, destination: $0.url) }
                } label: {
                    Image(systemName: "book").frame(width: 22, height: 22)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(S.guides)
            }
        }
        .padding(16)
        .background {
            // The game's own artwork, blurred, behind the header.
            AsyncImage(url: game.iconURL) { $0.resizable().scaledToFill() } placeholder: { Style.glow.opacity(0.25) }
                .blur(radius: 40).opacity(0.6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.08)))
    }

    private func pill(_ text: String, _ icon: String) -> some View {
        Label(text, systemImage: icon).font(.caption.weight(.medium)).lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .glassEffect(.regular, in: Capsule())
    }

    /// Platinum earned in the last week and not celebrated yet on this phone.
    private func celebrateIfNew() {
        guard let date = store.trophies.first(where: { $0.grade == .platinum && $0.earned })?.earnedDate,
              Date().timeIntervalSince(date) < 7 * 86_400 else { return }
        let key = "celebrated.\(game.id)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        celebrating = date
    }
}

/// Whether the phone has a network connection right now.
@MainActor
@Observable
final class Connectivity {
    static let shared = Connectivity()
    private(set) var online = true
    @ObservationIgnored private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { path in
            Task { @MainActor in Connectivity.shared.online = path.status == .satisfied }
        }
        monitor.start(queue: .global(qos: .utility))
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
    var canMark = true
    @State private var note = ""
    @State private var revealed = false
    @Environment(\.dismiss) private var dismiss
    private var targets: TrophyTargets { .shared }
    private var showcase: TrophyShowcase { .shared }
    private var local: Local { .shared }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ZStack {
                        Circle().fill(trophy.grade.color.opacity(0.25)).frame(width: 150, height: 150).blur(radius: 30)
                        Artwork(url: trophy.iconURL, size: 112)
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "trophy.circle.fill").font(.title).foregroundStyle(trophy.grade.color)
                                    .background(Circle().fill(.black)).offset(x: 8, y: 8)
                            }
                            .grayscale(trophy.earned ? 0 : 0.8)
                    }
                    VStack(spacing: 6) {
                        Text(trophy.name).font(.title2.bold()).multilineTextAlignment(.center)
                        if trophy.hidden && !trophy.earned && !revealed {
                            Button(S.revealSpoiler) { revealed = true }.font(.footnote)
                        } else {
                            Text(TrophyStore.shared.translatedDetails[trophy.id] ?? trophy.detail)
                                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                    }
                    rarity
                    if let date = trophy.earnedDate {
                        Label(date.shown(time: true), systemImage: "checkmark.seal.fill")
                            .font(.footnote.weight(.semibold)).foregroundStyle(Style.glow)
                    }
                    actions
                    if targets.isPinned(trophy, in: game) {
                        TextField(S.notePlaceholder, text: $note, axis: .vertical)
                            .onChange(of: note) { targets.setNote(note, for: trophy, in: game) }
                            .card(padding: 14)
                    }
                    VStack(spacing: 10) {
                        Link(destination: GuideLinks.forTrophy(trophy.name, game: game.name)) {
                            Label(S.searchYouTube, systemImage: "play.rectangle").frame(maxWidth: .infinity)
                        }
                        Link(destination: GuideLinks.webSearch(trophy.name, game: game.name)) {
                            Label(S.searchWebGuide, systemImage: "magnifyingglass").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.glass)
                }
                .padding(20)
            }
            .background(Style.backdrop.ignoresSafeArea())
            .toolbar { Button(S.close) { dismiss() } }
            .onAppear { note = targets.note(for: trophy, in: game) }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var rarity: some View {
        if let rate = trophy.earnedRate {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(trophy.rarity?.title ?? S.rarity).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(S.earnedBy(rate)).font(.caption).foregroundStyle(.secondary)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08))
                        Capsule().fill(trophy.grade.color.gradient).frame(width: max(6, proxy.size.width * rate / 100))
                    }
                }
                .frame(height: 8)
            }
            .card(padding: 14)
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            if trophy.earned {
                actionButton(showcase.contains(trophy, in: game) ? S.removeFromShowcase : S.addToShowcase, "star") {
                    showcase.toggle(trophy, in: game)
                }
            } else {
                actionButton(targets.isPinned(trophy, in: game) ? S.unpinTarget : S.pinTarget, "pin") {
                    targets.toggle(trophy, in: game)
                }
                if canMark {
                    actionButton(local.isDone(trophy, in: game) ? M.unmarkDone : M.markDone, "checkmark") {
                        local.toggleDone(trophy, in: game)
                    }
                }
            }
        }
    }

    private func actionButton(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptic.tap()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption.weight(.medium)).multilineTextAlignment(.center).lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
        }
        .buttonStyle(.glass)
    }
}

extension View {
    /// Swipe right to pin as a target, left to mark done; long press for the same and guides.
    /// `canMark` is false while online: PSN then knows what's done, so hand marks aren't offered.
    func trophyActions(_ trophy: Trophy, in game: TrophyGame, canMark: Bool = true) -> some View {
        let targets = TrophyTargets.shared
        let local = Local.shared
        return self
            .swipeActions(edge: .leading) {
                if !trophy.earned {
                    Button { targets.toggle(trophy, in: game); Haptic.tap() } label: {
                        Label(targets.isPinned(trophy, in: game) ? S.unpinTarget : S.pinTarget, systemImage: "pin")
                    }
                    .tint(Style.glow)
                }
            }
            .swipeActions(edge: .trailing) {
                if !trophy.earned && canMark {
                    Button { local.toggleDone(trophy, in: game); Haptic.tap() } label: {
                        Label(local.isDone(trophy, in: game) ? M.unmarkDone : M.markDone, systemImage: "checkmark")
                    }
                    .tint(.green)
                }
            }
            .contextMenu {
                if !trophy.earned {
                    Button(targets.isPinned(trophy, in: game) ? S.unpinTarget : S.pinTarget, systemImage: "pin") { targets.toggle(trophy, in: game) }
                    if canMark {
                        Button(local.isDone(trophy, in: game) ? M.unmarkDone : M.markDone, systemImage: "checkmark") { local.toggleDone(trophy, in: game) }
                    }
                }
                Link(destination: GuideLinks.forTrophy(trophy.name, game: game.name)) { Label(S.searchYouTube, systemImage: "play.rectangle") }
                Link(destination: GuideLinks.webSearch(trophy.name, game: game.name)) { Label(S.searchWebGuide, systemImage: "magnifyingglass") }
            }
    }
}
