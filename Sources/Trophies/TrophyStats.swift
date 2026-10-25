import Foundation

/// Numbers derived from the synced library. Pure calculations, no networking.
struct TrophyStats {
    struct Moment: Identifiable {
        let id = UUID()
        let title: String
        let trophy: Trophy
        let game: TrophyGame
    }

    struct Platinum: Identifiable {
        var id: String { game.id }
        let game: TrophyGame
        let earned: Date
        /// Time from the game's first trophy to its platinum.
        let duration: TimeInterval
    }

    struct Bucket: Identifiable {
        var id: String { label }
        let label: String
        let count: Int
        var order = 0
    }

    let earned: [(trophy: Trophy, game: TrophyGame, date: Date)]
    let platinums: [Platinum]

    init(_ entries: [TrophyLibrary.Entry]) {
        var all: [(Trophy, TrophyGame, Date)] = []
        var plats: [Platinum] = []
        for entry in entries {
            let mine = entry.trophies.compactMap { trophy -> (Trophy, TrophyGame, Date)? in
                guard trophy.earned, let date = trophy.earnedDate else { return nil }
                return (trophy, entry.game, date)
            }
            all += mine
            if let plat = mine.first(where: { $0.0.grade == .platinum }), let start = mine.map(\.2).min() {
                plats.append(Platinum(game: entry.game, earned: plat.2, duration: plat.2.timeIntervalSince(start)))
            }
        }
        earned = all.sorted { $0.2 < $1.2 }.map { (trophy: $0.0, game: $0.1, date: $0.2) }
        platinums = plats.sorted { $0.earned < $1.earned }
    }

    var isEmpty: Bool { earned.isEmpty }

    // MARK: Milestones

    func milestones() -> [Moment] {
        var moments: [Moment] = []
        if let first = earned.first {
            moments.append(Moment(title: S.milestoneFirstTrophy, trophy: first.trophy, game: first.game))
        }
        for count in [100, 250, 500, 1000, 2500, 5000, 10000] where earned.count >= count {
            let item = earned[count - 1]
            moments.append(Moment(title: S.milestoneTrophyNumber(count), trophy: item.trophy, game: item.game))
        }
        let platItems = earned.filter { $0.trophy.grade == .platinum }
        for (index, item) in platItems.enumerated() {
            let number = index + 1
            if number == 1 || number % 10 == 0 {
                moments.append(Moment(title: S.milestonePlatinumNumber(number), trophy: item.trophy, game: item.game))
            }
        }
        if let rarest = earned.filter({ $0.trophy.earnedRate != nil }).min(by: { $0.trophy.earnedRate! < $1.trophy.earnedRate! }) {
            moments.append(Moment(title: S.rarestEarned, trophy: rarest.trophy, game: rarest.game))
        }
        return moments
    }

    // MARK: Lists

    func rarest(limit: Int = 10) -> [(trophy: Trophy, game: TrophyGame, date: Date)] {
        Array(earned.filter { $0.trophy.earnedRate != nil }
            .sorted { $0.trophy.earnedRate! < $1.trophy.earnedRate! }
            .prefix(limit))
    }

    func fastestPlatinums(limit: Int = 10) -> [Platinum] {
        Array(platinums.sorted { $0.duration < $1.duration }.prefix(limit))
    }

    // MARK: Distributions

    func byMonth(last months: Int = 12, locale: Locale) -> [Bucket] {
        let calendar = Calendar.current
        let now = Date()
        var buckets: [Bucket] = []
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMM yy")
        for offset in stride(from: months - 1, through: 0, by: -1) {
            guard let month = calendar.date(byAdding: .month, value: -offset, to: now),
                  let interval = calendar.dateInterval(of: .month, for: month) else { continue }
            let count = earned.filter { interval.contains($0.date) }.count
            buckets.append(Bucket(label: formatter.string(from: interval.start), count: count, order: months - offset))
        }
        return buckets
    }

    func byYear() -> [Bucket] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: earned) { calendar.component(.year, from: $0.date) }
        return grouped.keys.sorted().map { Bucket(label: String($0), count: grouped[$0]!.count, order: $0) }
    }

    func byWeekday(locale: Locale) -> [Bucket] {
        var calendar = Calendar.current
        calendar.locale = locale
        let symbols = calendar.shortWeekdaySymbols
        let counts = Dictionary(grouping: earned) { calendar.component(.weekday, from: $0.date) }.mapValues(\.count)
        // Start the week on the locale's first day.
        return (0..<7).map { step in
            let weekday = (calendar.firstWeekday - 1 + step) % 7 + 1
            return Bucket(label: symbols[weekday - 1], count: counts[weekday] ?? 0, order: step)
        }
    }

    func byHour() -> [Bucket] {
        let calendar = Calendar.current
        let counts = Dictionary(grouping: earned) { calendar.component(.hour, from: $0.date) }.mapValues(\.count)
        return (0..<24).map { Bucket(label: String(format: "%02d", $0), count: counts[$0] ?? 0, order: $0) }
    }

    func byGrade() -> [TrophyGrade: Int] {
        Dictionary(grouping: earned, by: \.trophy.grade).mapValues(\.count)
    }

    func byRarity() -> [TrophyRarity: Int] {
        Dictionary(grouping: earned.compactMap(\.trophy.rarity), by: { $0 }).mapValues(\.count)
    }

    // MARK: Streaks

    /// Longest run of consecutive days with at least one trophy, and the run that's still going.
    func streaks() -> (longest: Int, current: Int) {
        let calendar = Calendar.current
        let days = Set(earned.map { calendar.startOfDay(for: $0.date) }).sorted()
        guard !days.isEmpty else { return (0, 0) }
        var longest = 1
        var run = 1
        for index in 1..<days.count {
            let gap = calendar.dateComponents([.day], from: days[index - 1], to: days[index]).day ?? 0
            run = gap == 1 ? run + 1 : 1
            longest = max(longest, run)
        }
        let today = calendar.startOfDay(for: Date())
        let sinceLast = calendar.dateComponents([.day], from: days.last!, to: today).day ?? 99
        return (longest, sinceLast <= 1 ? run : 0)
    }

    var busiestDay: (date: Date, count: Int)? {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: earned) { calendar.startOfDay(for: $0.date) }
        guard let best = grouped.max(by: { $0.value.count < $1.value.count }) else { return nil }
        return (best.key, best.value.count)
    }
}
