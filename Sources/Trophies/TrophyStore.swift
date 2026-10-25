import Foundation
import Observation

/// State behind the trophies window.
@MainActor
@Observable
final class TrophyStore {
    static let shared = TrophyStore()

    enum Filter: String, CaseIterable, Identifiable {
        case missing = "Eksikler"
        case all = "Tümü"
        case earned = "Kazanılanlar"
        var id: String { rawValue }
    }

    enum Order: String, CaseIterable, Identifiable {
        case easiest = "En kolay önce"
        case rarest = "En nadir önce"
        case original = "Oyun sırası"
        var id: String { rawValue }
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

    private func translateDetails() {
        let prefs = Preferences.shared
        let pending = trophies.filter { translatedDetails[$0.id] == nil && !$0.detail.isEmpty }
        Task {
            for trophy in pending {
                // Trophy text is written in the account's PSN language; English is the common case.
                if let text = try? await Translator.shared.translate(trophy.detail, from: "en", to: prefs.targetLanguage) {
                    translatedDetails[trophy.id] = text
                }
            }
        }
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
