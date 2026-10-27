import Foundation
import Observation

/// Every game's trophies, kept on disk so statistics work across the whole history.
///
/// The first sync visits every game once (two requests each, spaced out by the client).
/// After that only games whose `lastUpdatedDateTime` moved are fetched again.
@MainActor
@Observable
final class TrophyLibrary {
    struct Entry: Codable {
        var game: TrophyGame
        var trophies: [Trophy]
    }

    struct Snapshot: Codable {
        var entries: [String: Entry] = [:]
        var syncedAt: Date?
        /// Last known game list and profile, shown immediately while fresh data loads.
        var games: [TrophyGame]?
        var profile: TrophyProfile?
    }

    static let shared = TrophyLibrary()

    private(set) var snapshot = Snapshot()
    private(set) var syncing = false
    private(set) var syncDone = 0
    private(set) var syncTotal = 0
    private(set) var syncProblem: String?
    @ObservationIgnored private var syncTask: Task<Void, Never>?

    var hasData: Bool { snapshot.syncedAt != nil }
    var entries: [Entry] { Array(snapshot.entries.values) }

    private static var fileURL: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tercana", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("trophies.json")
    }

    private init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = saved
        }
    }

    /// Brings the library up to date with `games` (the fresh title list).
    func sync(with games: [TrophyGame]) {
        guard !syncing else { return }
        let stale = games.filter { game in
            guard game.earnedTrophies.total > 0 else { return false }
            return snapshot.entries[game.id]?.game.lastUpdatedDateTime != game.lastUpdatedDateTime
        }
        // Keep the stored game info current even when its trophies didn't change.
        for game in games where snapshot.entries[game.id] != nil {
            snapshot.entries[game.id]?.game = game
        }
        guard !stale.isEmpty else {
            snapshot.syncedAt = Date()
            save()
            return
        }

        syncing = true
        syncDone = 0
        syncTotal = stale.count
        syncProblem = nil
        syncTask = Task {
            for game in stale {
                if Task.isCancelled { break }
                do {
                    let trophies = try await PSNClient.shared.trophies(for: game)
                    snapshot.entries[game.id] = Entry(game: game, trophies: trophies)
                } catch {
                    syncProblem = error.localizedDescription
                    if case .expiredLogin? = error as? PSNError { break }
                }
                syncDone += 1
                if syncDone % 10 == 0 { save() }
            }
            snapshot.syncedAt = Date()
            save()
            syncing = false
        }
    }

    /// Local preview renderer only; never saved.
    func usePreviewData(_ entries: [Entry]) {
        snapshot = Snapshot(entries: Dictionary(uniqueKeysWithValues: entries.map { ($0.game.id, $0) }),
                            syncedAt: Date())
    }

    func remember(games: [TrophyGame], profile: TrophyProfile?) {
        snapshot.games = games
        if let profile { snapshot.profile = profile }
        save()
    }

    func cancelSync() {
        syncTask?.cancel()
    }

    func reset() {
        guard ProcessInfo.processInfo.environment["TERCANA_PREVIEW"] == nil else { snapshot = Snapshot(); return }
        cancelSync()
        snapshot = Snapshot()
        try? FileManager.default.removeItem(at: Self.fileURL)
    }

    private func save() {
        // The preview tool shares this code but must never write over the real library.
        guard ProcessInfo.processInfo.environment["TERCANA_PREVIEW"] == nil else { return }
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }
}

/// A pinned showcase of trophies the player is proud of, kept on this Mac.
@MainActor
@Observable
final class TrophyShowcase {
    struct Item: Codable, Identifiable, Hashable {
        let gameID: String
        let gameName: String
        let trophy: Trophy
        var id: String { TrophyTargets.key(gameID, trophy.id) }
    }

    static let shared = TrophyShowcase()
    private static let defaultsKey = "trophyShowcase"

    private(set) var items: [Item] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: Self.defaultsKey) }
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode([Item].self, from: data) {
            items = saved
        }
    }

    func contains(_ trophy: Trophy, in game: TrophyGame) -> Bool {
        items.contains { $0.id == TrophyTargets.key(game.id, trophy.id) }
    }

    func toggle(_ trophy: Trophy, in game: TrophyGame) {
        let key = TrophyTargets.key(game.id, trophy.id)
        if let index = items.firstIndex(where: { $0.id == key }) {
            items.remove(at: index)
        } else {
            items.append(Item(gameID: game.id, gameName: game.name, trophy: trophy))
        }
    }
}
