import Foundation

/// PSN trophy level math (the 2020 system): points per trophy and points per level band.
enum Level {
    static func points(_ grade: TrophyGrade) -> Int {
        switch grade {
        case .bronze: return 15
        case .silver: return 30
        case .gold: return 90
        case .platinum: return 300
        }
    }

    static func points(_ counts: TrophyCounts) -> Int {
        counts.bronze * 15 + counts.silver * 30 + counts.gold * 90 + counts.platinum * 300
    }

    /// Points needed to go from `level` to `level + 1`.
    static func cost(at level: Int) -> Int {
        switch level {
        case ..<100: return 60
        case ..<200: return 90
        default: return 450 * ((level / 100) - 1)
        }
    }

    /// Points still missing from the current level (with `progress` percent done) to `target`.
    static func pointsNeeded(from level: Int, progress: Int, to target: Int) -> Int {
        guard target > level else { return 0 }
        var total = cost(at: level) * (100 - progress) / 100
        for step in (level + 1)..<target { total += cost(at: step) }
        return total
    }
}
