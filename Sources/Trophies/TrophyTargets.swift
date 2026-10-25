import Foundation
import Observation

/// Trophies the player has pinned as goals, with their own notes ("missable in chapter 3").
/// Stored only on this Mac.
@MainActor
@Observable
final class TrophyTargets {
    struct Target: Codable, Identifiable, Hashable {
        let gameID: String
        let gameName: String
        let trophyID: Int
        var trophyName: String
        var note: String
        let added: Date

        var id: String { TrophyTargets.key(gameID, trophyID) }
    }

    static let shared = TrophyTargets()
    private static let defaultsKey = "trophyTargets"

    private(set) var items: [String: Target] = [:] {
        didSet { save() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode([String: Target].self, from: data) {
            items = saved
        }
    }

    var sorted: [Target] { items.values.sorted { $0.added > $1.added } }

    func isPinned(_ trophy: Trophy, in game: TrophyGame) -> Bool {
        items[Self.key(game.id, trophy.id)] != nil
    }

    func toggle(_ trophy: Trophy, in game: TrophyGame) {
        let key = Self.key(game.id, trophy.id)
        if items[key] != nil {
            items[key] = nil
        } else {
            items[key] = Target(gameID: game.id, gameName: game.name, trophyID: trophy.id,
                                trophyName: trophy.name, note: "", added: Date())
        }
    }

    func note(for trophy: Trophy, in game: TrophyGame) -> String {
        items[Self.key(game.id, trophy.id)]?.note ?? ""
    }

    func setNote(_ note: String, for trophy: Trophy, in game: TrophyGame) {
        let key = Self.key(game.id, trophy.id)
        if items[key] == nil { toggle(trophy, in: game) }
        items[key]?.note = note
    }

    func setNote(_ note: String, forKey key: String) {
        items[key]?.note = note
    }

    func remove(_ target: Target) {
        items[target.id] = nil
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    nonisolated static func key(_ gameID: String, _ trophyID: Int) -> String { "\(gameID)#\(trophyID)" }
}
