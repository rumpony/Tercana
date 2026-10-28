import Foundation
import Observation

/// Points ranking among you and your PSN friends. Refreshed only when asked (one request per
/// friend, about a second each), never in the background. Each refresh is kept so the page can
/// show how rank and points moved since earlier today and since yesterday.
@MainActor
@Observable
final class Leaderboard {
    static let shared = Leaderboard()

    struct Row: Codable, Identifiable {
        let player: PSNClient.Player
        let level: Int
        let points: Int
        let counts: TrophyCounts
        var id: String { player.id }
    }

    struct Snapshot: Codable {
        let date: Date
        let rows: [Row]
        let me: String
        var myRank: Int? { rows.firstIndex { $0.player.id == me }.map { $0 + 1 } }
        var myPoints: Int? { rows.first { $0.player.id == me }?.points }
    }

    private(set) var history: [Snapshot] = [] {
        didSet { try? JSONEncoder().encode(history).write(to: Self.url) }
    }
    private(set) var refreshing = false
    private(set) var done = 0
    private(set) var total = 0
    private(set) var me: PSNClient.Player?

    var latest: Snapshot? { history.last }

    /// The first refresh of today, to show "today" movement.
    var startOfToday: Snapshot? {
        history.first { Calendar.current.isDateInToday($0.date) }
    }

    /// The last refresh before today.
    var yesterday: Snapshot? {
        history.last { !Calendar.current.isDateInToday($0.date) }
    }

    private static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tercana/leaderboard.json")
    }

    private init() {
        history = (try? Data(contentsOf: Self.url)).flatMap { try? JSONDecoder().decode([Snapshot].self, from: $0) } ?? []
    }

    func refresh() async {
        guard !refreshing, !Demo.isOn else { return }
        refreshing = true
        defer { refreshing = false }
        guard let me = try? await PSNClient.shared.me(), let friends = try? await PSNClient.shared.friends() else { return }
        self.me = me
        let players = [me] + friends
        total = players.count
        done = 0
        var rows: [Row] = []
        for player in players {
            // Private trophy lists answer with an error; those friends are left out.
            if let profile = try? await PSNClient.shared.profile(user: player.id == me.id ? "me" : player.id) {
                rows.append(Row(player: player, level: profile.level, points: Level.points(profile.earnedTrophies),
                                counts: profile.earnedTrophies))
            }
            done += 1
        }
        rows.sort { $0.points > $1.points }
        history.append(Snapshot(date: Date(), rows: rows, me: me.id))
        // A week of refreshes is plenty for the comparisons shown.
        history.removeAll { $0.date < Date().addingTimeInterval(-7 * 86_400) }
    }

    func useDemo(_ snapshot: Snapshot) { history = [snapshot] }
}
