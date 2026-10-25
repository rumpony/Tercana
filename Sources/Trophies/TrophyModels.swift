import Foundation

struct TrophyCounts: Decodable, Hashable {
    var bronze = 0
    var silver = 0
    var gold = 0
    var platinum = 0

    var total: Int { bronze + silver + gold + platinum }
}

/// A game in the player's trophy list.
struct TrophyGame: Decodable, Identifiable, Hashable {
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

enum TrophyGrade: String, Decodable {
    case bronze, silver, gold, platinum

    var label: String {
        switch self {
        case .bronze: return "Bronz"
        case .silver: return "Gümüş"
        case .gold: return "Altın"
        case .platinum: return "Platin"
        }
    }
}

/// Trophy definition merged with the player's progress on it.
struct Trophy: Identifiable, Hashable {
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
