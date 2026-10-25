import Foundation
import NaturalLanguage
import Observation

/// State behind the trophies window.
@MainActor
@Observable
final class TrophyStore {
    static let shared = TrophyStore()

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

    private(set) var signedIn = false
    private(set) var games: [TrophyGame] = []
    private(set) var trophies: [Trophy] = []
    private(set) var nowPlaying: String?
    private(set) var loading = false
    private(set) var problem: String?
    var selectedGameID: String?
    var filter: Filter = .missing
    var order: Order = .easiest
    var searchText = ""
    /// Trophy descriptions translated into the user's language, keyed by trophy id.
    private(set) var translatedDetails: [Int: String] = [:]
    var showTranslations = false {
        didSet { if showTranslations { translateDetails() } }
    }

    var selectedGame: TrophyGame? { games.first { $0.id == selectedGameID } }

    var visibleGames: [TrophyGame] {
        guard !searchText.isEmpty else { return games }
        return games.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var visibleTrophies: [Trophy] {
        let filtered: [Trophy]
        switch filter {
        case .all: filtered = trophies
        case .missing: filtered = trophies.filter { !$0.earned }
        case .earned: filtered = trophies.filter(\.earned)
        }
        switch order {
        case .original: return filtered
        case .easiest: return filtered.sorted { ($0.earnedRate ?? 0) > ($1.earnedRate ?? 0) }
        case .rarest: return filtered.sorted { ($0.earnedRate ?? 100) < ($1.earnedRate ?? 100) }
        }
    }

    /// Trophy text follows the interface language; the window is rebuilt on a switch, which reloads it.
    func load() async {
        signedIn = await PSNClient.shared.isSignedIn
        guard signedIn else { return }
        await run {
            self.games = try await PSNClient.shared.games()
            self.nowPlaying = try? await PSNClient.shared.currentGameName()
            if self.selectedGameID == nil {
                self.selectedGameID = self.matchingGame(self.nowPlaying)?.id ?? self.games.first?.id
            }
        }
        await loadTrophies()
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
        games = []
        trophies = []
        nowPlaying = nil
        selectedGameID = nil
    }

    func select(_ gameID: String?) async {
        selectedGameID = gameID
        await loadTrophies()
    }

    /// Jumps to the game PSN says is running now.
    func showNowPlaying() async {
        nowPlaying = try? await PSNClient.shared.currentGameName()
        if let game = matchingGame(nowPlaying) { await select(game.id) }
    }

    private func loadTrophies() async {
        guard let game = selectedGame else { trophies = []; return }
        translatedDetails = [:]
        await run {
            let loaded = try await PSNClient.shared.trophies(for: game)
            if self.selectedGameID == game.id { self.trophies = loaded }
        }
        if showTranslations { translateDetails() }
    }

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
