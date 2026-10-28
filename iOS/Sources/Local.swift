import Foundation
import Observation

/// Phone-only lists kept on the device: games on the hunt list and trophies marked done by hand
/// (for progress PSN doesn't sync, e.g. a checklist while following a guide).
@MainActor
@Observable
final class Local {
    static let shared = Local()

    private(set) var hunting: [String] = UserDefaults.standard.stringArray(forKey: "hunting") ?? [] {
        didSet { UserDefaults.standard.set(hunting, forKey: "hunting") }
    }
    private(set) var done: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "markedDone") ?? []) {
        didSet { UserDefaults.standard.set(Array(done), forKey: "markedDone") }
    }

    func isHunting(_ game: TrophyGame) -> Bool { hunting.contains(game.id) }

    func toggleHunting(_ game: TrophyGame) {
        if let index = hunting.firstIndex(of: game.id) { hunting.remove(at: index) } else { hunting.insert(game.id, at: 0) }
    }

    func isDone(_ trophy: Trophy, in game: TrophyGame) -> Bool { done.contains(TrophyTargets.key(game.id, trophy.id)) }

    func toggleDone(_ trophy: Trophy, in game: TrophyGame) {
        let key = TrophyTargets.key(game.id, trophy.id)
        if done.contains(key) { done.remove(key) } else { done.insert(key) }
    }
}
