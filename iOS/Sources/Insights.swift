import Foundation

/// Calculations the phone adds on top of TrophyStats, all from the synced library.
enum Insights {
    typealias Earned = (trophy: Trophy, game: TrophyGame, date: Date)

    /// Trophies per calendar day over the last `days` days.
    static func perDay(_ earned: [Earned], days: Int = 120) -> [Date: Int] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: Date()))!
        var counts: [Date: Int] = [:]
        for item in earned where item.date >= start {
            counts[calendar.startOfDay(for: item.date), default: 0] += 1
        }
        return counts
    }

    /// Trophies earned on today's date in earlier years, newest year first.
    static func onThisDay(_ earned: [Earned]) -> [Earned] {
        let calendar = Calendar.current
        let today = calendar.dateComponents([.month, .day, .year], from: Date())
        return earned.filter {
            let parts = calendar.dateComponents([.month, .day, .year], from: $0.date)
            return parts.month == today.month && parts.day == today.day && parts.year != today.year
        }
        .sorted { $0.date > $1.date }
    }

    struct Year {
        let year: Int
        let trophies: Int
        let platinums: [TrophyGame]
        let points: Int
        let bestMonth: (month: Int, count: Int)?
        let rarest: Earned?
        let games: Int
    }

    static func years(_ earned: [Earned]) -> [Int] {
        Array(Set(earned.map { Calendar.current.component(.year, from: $0.date) })).sorted(by: >)
    }

    static func year(_ year: Int, _ earned: [Earned]) -> Year {
        let calendar = Calendar.current
        let items = earned.filter { calendar.component(.year, from: $0.date) == year }
        let months = Dictionary(grouping: items) { calendar.component(.month, from: $0.date) }.mapValues(\.count)
        let best = months.max { $0.value < $1.value }.map { (month: $0.key, count: $0.value) }
        return Year(year: year, trophies: items.count,
                    platinums: items.filter { $0.trophy.grade == .platinum }.map(\.game),
                    points: items.reduce(0) { $0 + Level.points($1.trophy.grade) },
                    bestMonth: best,
                    rarest: items.filter { $0.trophy.earnedRate != nil }.min { $0.trophy.earnedRate! < $1.trophy.earnedRate! },
                    games: Set(items.map(\.game.id)).count)
    }

    /// Missing trophies with the highest earn rate, in games already started.
    static func nextUp(_ entries: [TrophyLibrary.Entry], limit: Int = 15) -> [(trophy: Trophy, game: TrophyGame)] {
        entries.filter { $0.game.progress > 0 }
            .flatMap { entry in entry.trophies.filter { !$0.earned && $0.grade != .platinum }.map { (trophy: $0, game: entry.game) } }
            .sorted { ($0.trophy.earnedRate ?? 0) > ($1.trophy.earnedRate ?? 0) }
            .prefix(limit).map { $0 }
    }

    /// Mean earn rate of the player's trophies; lower means a rarer collection.
    static func averageRarity(_ earned: [Earned]) -> Double? {
        let rates = earned.compactMap(\.trophy.earnedRate)
        return rates.isEmpty ? nil : rates.reduce(0, +) / Double(rates.count)
    }

    /// Days to the platinum at the pace so far (trophies per active day span).
    static func platinumETA(_ trophies: [Trophy]) -> Int? {
        let earned = trophies.filter(\.earned).compactMap(\.earnedDate)
        guard trophies.contains(where: { $0.grade == .platinum && !$0.earned }),
              earned.count >= 3, let first = earned.min() else { return nil }
        let days = max(1, Date().timeIntervalSince(first) / 86_400)
        let remaining = trophies.filter { !$0.earned && $0.grade != .platinum }.count
        return Int((Double(remaining) / (Double(earned.count) / days)).rounded(.up))
    }
}
