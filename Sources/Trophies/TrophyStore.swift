import Foundation
import NaturalLanguage
import Observation

/// State behind the trophies window.
@MainActor
@Observable
final class TrophyStore {
    static let shared = TrophyStore()

    enum Page: Hashable {
        case profile, closest, recent, platinums, targets
        case game(String)
    }

    enum Filter: String, CaseIterable, Identifiable {
        case missing, all, earned
        var id: String { rawValue }
        var title: String {
            switch self {
            case .missing: return S.filterMissing
            case .all: return S.filterAll
            case .earned: return S.filterEarned
            }
        }
    }

    enum Order: String, CaseIterable, Identifiable {
        case easiest, rarest, original
        var id: String { rawValue }
        var title: String {
            switch self {
            case .easiest: return S.orderEasiest
            case .rarest: return S.orderRarest
            case .original: return S.orderGame
            }
        }
    }

    /// A trophy earned in some game, for the cross-game timeline.
    struct Earned: Identifiable {
        let trophy: Trophy
        let game: TrophyGame
        var id: String { TrophyTargets.key(game.id, trophy.id) }
    }

    private(set) var signedIn = false
    private(set) var profile: TrophyProfile?
    private(set) var games: [TrophyGame] = []
    private(set) var trophies: [Trophy] = []
    private(set) var recent: [Earned] = []
    private(set) var loadingRecent = false
    private(set) var nowPlaying: String?
    private(set) var loading = false
    private(set) var problem: String?
    var page: Page = .profile
    var filter: Filter = .missing
    var order: Order = .easiest
    var rarityFilter: TrophyRarity?
    var searchText = ""
    /// Descriptions Sony had no text for in the interface language, machine-translated, by trophy id.
    private(set) var translatedDetails: [Int: String] = [:]
    var showTranslations = false {
        didSet { if showTranslations { translateDetails() } }
    }

    var selectedGame: TrophyGame? {
        guard case .game(let id) = page else { return nil }
        return games.first { $0.id == id }
    }

    var visibleGames: [TrophyGame] {
        guard !searchText.isEmpty else { return games }
        return games.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// Started but unfinished games, nearest to 100% first.
    var closestGames: [TrophyGame] {
        games.filter { $0.progress > 0 && $0.progress < 100 }.sorted { $0.progress > $1.progress }
    }

    var platinumGames: [TrophyGame] { games.filter(\.platinumEarned) }

    var completedCount: Int { games.filter { $0.progress == 100 }.count }

    var averageCompletion: Double {
        guard !games.isEmpty else { return 0 }
        return Double(games.map(\.progress).reduce(0, +)) / Double(games.count) / 100
    }

    var visibleTrophies: [Trophy] {
        var list: [Trophy]
        switch filter {
        case .all: list = trophies
        case .missing: list = trophies.filter { !$0.earned }
        case .earned: list = trophies.filter(\.earned)
        }
        if let rarityFilter { list = list.filter { $0.rarity == rarityFilter } }
        switch order {
        case .original: return list
        case .easiest: return list.sorted { ($0.earnedRate ?? 0) > ($1.earnedRate ?? 0) }
        case .rarest: return list.sorted { ($0.earnedRate ?? 100) < ($1.earnedRate ?? 100) }
        }
    }

    /// First and last trophy dates of the selected game, and its rarest earned trophy.
    var gameStats: (first: Date, last: Date, rarest: Trophy?)? {
        let earned = trophies.filter(\.earned)
        let dates = earned.compactMap(\.earnedDate)
        guard let first = dates.min(), let last = dates.max() else { return nil }
        let rarest = earned.filter { $0.earnedRate != nil }.min { $0.earnedRate! < $1.earnedRate! }
        return (first, last, rarest)
    }

    // MARK: Loading

    func load() async {
        signedIn = await PSNClient.shared.isSignedIn
        guard signedIn else { return }
        await run {
            async let profile = PSNClient.shared.profile()
            self.games = try await PSNClient.shared.games()
            self.profile = try? await profile
            self.nowPlaying = try? await PSNClient.shared.currentGameName()
        }
        if let playing = matchingGame(nowPlaying), page == .profile {
            await open(.game(playing.id))
        } else {
            await open(page)
        }
    }

    func open(_ page: Page) async {
        self.page = page
        switch page {
        case .game: await loadTrophies()
        case .recent: await loadRecent()
        default: break
        }
    }

    func signIn(sessionToken: String) async {
        await run {
            try await PSNClient.shared.signIn(sessionToken: sessionToken)
        }
        await load()
    }

    func signOut() async {
        await PSNClient.shared.signOut()
        signedIn = false
        profile = nil
        games = []
        trophies = []
        recent = []
        nowPlaying = nil
        page = .profile
    }

    /// Jumps to the game PSN says is running now.
    func showNowPlaying() async {
        nowPlaying = try? await PSNClient.shared.currentGameName()
        if let game = matchingGame(nowPlaying) { await open(.game(game.id)) }
    }

    private func loadTrophies() async {
        guard let game = selectedGame else { trophies = []; return }
        translatedDetails = [:]
        trophies = []
        await run {
            let loaded = try await PSNClient.shared.trophies(for: game)
            if self.selectedGame?.id == game.id { self.trophies = loaded }
        }
        if showTranslations { translateDetails() }
    }

    /// Gathers recently earned trophies from the few games played most recently.
    /// Kept small on purpose: every game costs two requests.
    private func loadRecent() async {
        guard !loadingRecent else { return }
        loadingRecent = true
        defer { loadingRecent = false }
        let latest = games.filter { $0.earnedTrophies.total > 0 }
            .sorted { ($0.lastUpdatedDateTime ?? "") > ($1.lastUpdatedDateTime ?? "") }
            .prefix(6)
        var collected: [Earned] = []
        for game in latest {
            guard let list = try? await PSNClient.shared.trophies(for: game) else { continue }
            collected += list.filter { $0.earned && $0.earnedDate != nil }.map { Earned(trophy: $0, game: game) }
            recent = Array(collected.sorted { $0.trophy.earnedDate! > $1.trophy.earnedDate! }.prefix(60))
        }
    }

    // MARK: Helpers

    /// Machine-translates only the descriptions Sony couldn't give us in the interface language.
    private func translateDetails() {
        let target = AppLanguage.current.resolved.rawValue
        let pending = trophies.filter { translatedDetails[$0.id] == nil && !$0.detail.isEmpty }
        Task {
            for trophy in pending {
                guard let source = Self.language(of: trophy.detail), source != target else { continue }
                if let text = try? await Translator.shared.translate(trophy.detail, from: source, to: target) {
                    translatedDetails[trophy.id] = text
                }
            }
        }
    }

    private static func language(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else { return nil }
        return language == .simplifiedChinese ? "zh-Hans" : language.rawValue
    }

    private func matchingGame(_ name: String?) -> TrophyGame? {
        guard let name else { return nil }
        let key = Self.normalize(name)
        return games.first { Self.normalize($0.name) == key }
            ?? games.first { Self.normalize($0.name).hasPrefix(key) || key.hasPrefix(Self.normalize($0.name)) }
    }

    private static func normalize(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func run(_ work: @escaping () async throws -> Void) async {
        loading = true
        problem = nil
        do {
            try await work()
        } catch {
            problem = error.localizedDescription
            if case .expiredLogin? = error as? PSNError { signedIn = false }
        }
        loading = false
    }
}
