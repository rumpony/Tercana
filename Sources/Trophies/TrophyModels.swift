import Foundation

struct TrophyCounts: Codable, Hashable {
    var bronze = 0
    var silver = 0
    var gold = 0
    var platinum = 0

    var total: Int { bronze + silver + gold + platinum }
}

/// A game in the player's trophy list.
struct TrophyGame: Codable, Identifiable, Hashable {
    let npServiceName: String
    let npCommunicationId: String
    let trophyTitleName: String
    let trophyTitleIconUrl: String?
    let trophyTitlePlatform: String?
    let definedTrophies: TrophyCounts
    let earnedTrophies: TrophyCounts
    let progress: Int
    let lastUpdatedDateTime: String?

    var id: String { npCommunicationId }
    var name: String { trophyTitleName }
    var iconURL: URL? { trophyTitleIconUrl.flatMap(URL.init(string:)) }
    var platform: String { (trophyTitlePlatform ?? "").replacingOccurrences(of: ",", with: " · ") }
    var hasPlatinum: Bool { definedTrophies.platinum > 0 }
    var platinumEarned: Bool { earnedTrophies.platinum > 0 }
}

enum TrophyGrade: String, Codable, CaseIterable {
    case bronze, silver, gold, platinum

    var label: String {
        switch self {
        case .bronze: return S.bronze
        case .silver: return S.silver
        case .gold: return S.gold
        case .platinum: return S.platinum
        }
    }
}

/// PSN's own rarity buckets (the `trophyRare` field).
enum TrophyRarity: Int, Codable, CaseIterable, Identifiable, Comparable {
    case ultraRare = 0, veryRare, rare, common

    var id: Int { rawValue }

    static func < (lhs: TrophyRarity, rhs: TrophyRarity) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Fallback when only the percentage is known; same thresholds PSN uses.
    init(rate: Double) {
        switch rate {
        case ..<5: self = .ultraRare
        case ..<15: self = .veryRare
        case ..<50: self = .rare
        default: self = .common
        }
    }
}

struct TrophyProfile: Codable {
    let level: Int
    let progress: Int
    let tier: Int
    let earnedTrophies: TrophyCounts

    private enum CodingKeys: String, CodingKey { case trophyLevel, progress, tier, earnedTrophies }

    /// Sony has sent the level both as a string and as a number; accept either.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let text = try? c.decode(String.self, forKey: .trophyLevel) {
            level = Int(text) ?? 0
        } else {
            level = (try? c.decode(Int.self, forKey: .trophyLevel)) ?? 0
        }
        progress = (try? c.decode(Int.self, forKey: .progress)) ?? 0
        tier = (try? c.decode(Int.self, forKey: .tier)) ?? 1
        earnedTrophies = try c.decode(TrophyCounts.self, forKey: .earnedTrophies)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(String(level), forKey: .trophyLevel)
        try c.encode(progress, forKey: .progress)
        try c.encode(tier, forKey: .tier)
        try c.encode(earnedTrophies, forKey: .earnedTrophies)
    }
}

/// Trophy definition merged with the player's progress on it.
struct Trophy: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let detail: String
    let grade: TrophyGrade
    let hidden: Bool
    let iconURL: URL?
    let groupId: String?
    var earned = false
    var earnedDate: Date?
    /// Share of players who have it, e.g. 12.4 for 12.4%.
    var earnedRate: Double?
    var rarity: TrophyRarity?
    var progress: String?
    var progressTarget: String?
}

// MARK: - Raw API payloads

struct TrophyGamesPage: Decodable {
    let trophyTitles: [TrophyGame]
    let totalItemCount: Int
    let nextOffset: Int?
}

struct TrophyDefinitionsPayload: Decodable {
    struct Item: Decodable {
        let trophyId: Int
        let trophyHidden: Bool?
        let trophyType: TrophyGrade
        let trophyName: String?
        let trophyDetail: String?
        let trophyIconUrl: String?
        let trophyGroupId: String?
    }
    let trophies: [Item]
}

struct TrophyProgressPayload: Decodable {
    struct Item: Decodable {
        let trophyId: Int
        let earned: Bool?
        let earnedDateTime: String?
        let trophyEarnedRate: String?
        let trophyRare: Int?
        let progress: String?
        let trophyProgressTargetValue: String?
    }
    let trophies: [Item]
}

struct PresencePayload: Decodable {
    struct Basic: Decodable {
        struct GameInfo: Decodable {
            let npTitleId: String?
            let titleName: String?
        }
        let availability: String?
        let gameTitleInfoList: [GameInfo]?
    }
    let basicPresence: Basic
}
