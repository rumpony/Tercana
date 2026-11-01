import Foundation
import Observation

/// Trophies friends earned lately, built from the games they played in the last two weeks.
@MainActor @Observable
final class FriendFeed {
    static let shared = FriendFeed()

    struct Item: Identifiable {
        let player: PSNClient.Player
        let game: TrophyGame
        let trophy: Trophy
        let date: Date
        var id: String { "\(player.id)-\(game.id)-\(trophy.id)" }
    }

    private(set) var items: [Item] = []
    private(set) var loading = false

    func refresh(_ friends: [PSNClient.Player]) async {
        guard !loading, !Demo.isOn else { return }
        loading = true
        defer { loading = false }
        let since = Date().addingTimeInterval(-14 * 86_400)
        let cutoff = ISO8601DateFormatter().string(from: since)
        var collected: [Item] = []
        for friend in friends {
            // Private trophy lists answer with an error; those friends are skipped.
            guard let games = try? await PSNClient.shared.games(user: friend.id) else { continue }
            let recent = games.filter { ($0.lastUpdatedDateTime ?? "") >= cutoff }
                .sorted { ($0.lastUpdatedDateTime ?? "") > ($1.lastUpdatedDateTime ?? "") }
                .prefix(2)
            for game in recent {
                guard let trophies = try? await PSNClient.shared.trophies(for: game, user: friend.id) else { continue }
                collected += trophies.compactMap { trophy in
                    guard trophy.earned, let date = trophy.earnedDate, date >= since else { return nil }
                    return Item(player: friend, game: game, trophy: trophy, date: date)
                }
            }
            items = Array(collected.sorted { $0.date > $1.date }.prefix(100))
        }
    }
}
