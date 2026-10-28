import Foundation

/// Fictional data for checking screens in the simulator without a PSN account.
/// Active only when the TERCANA_PREVIEW environment variable is set, which also keeps
/// the stores away from real files.
@MainActor
enum Demo {
    static var isOn: Bool { ProcessInfo.processInfo.environment["TERCANA_PREVIEW"] != nil }

    static func load() {
        func counts(_ p: Int, _ g: Int, _ s: Int, _ b: Int) -> TrophyCounts { TrophyCounts(bronze: b, silver: s, gold: g, platinum: p) }
        let titles = [("Shadows of Velmora", 62), ("Neon Drift", 97), ("The Last Lighthouse", 100), ("Kingdom of Ash", 88),
                      ("Starfall Odyssey", 45), ("Paper Garden", 100), ("Iron Hollow", 23), ("Echoes of Tarsis", 74)]
        let games = titles.enumerated().map { i, item in
            TrophyGame(npServiceName: "trophy2", npCommunicationId: "G\(i)", trophyTitleName: item.0,
                       trophyTitleIconUrl: nil, trophyTitlePlatform: "PS5",
                       definedTrophies: counts(1, 6, 12, 28),
                       earnedTrophies: counts(item.1 == 100 ? 1 : 0, item.1 / 18, item.1 / 9, item.1 / 4),
                       progress: item.1, lastUpdatedDateTime: nil)
        }
        func ago(_ days: Int) -> Date { Date().addingTimeInterval(-Double(days) * 86_400 - 3600) }
        func trophy(_ id: Int, _ name: String, _ detail: String, _ grade: TrophyGrade, _ rate: Double, earned: Date? = nil) -> Trophy {
            var t = Trophy(id: id, name: name, detail: detail, grade: grade, hidden: false, iconURL: nil, groupId: "default")
            t.earned = earned != nil; t.earnedDate = earned; t.earnedRate = rate; t.rarity = TrophyRarity(rate: rate)
            return t
        }
        let list = [
            trophy(1, "Lightkeeper", "Restore every lighthouse along the northern coast.", .gold, 8.4),
            trophy(2, "Silent Tide", "Cross the harbor without being spotted.", .silver, 21.6),
            trophy(3, "Velmora's Heir", "Collect all other trophies.", .platinum, 3.2),
            trophy(5, "First Light", "Complete the prologue.", .bronze, 94.0, earned: ago(9)),
            trophy(6, "Cartographer", "Uncover the whole map.", .silver, 34.7, earned: ago(3)),
        ]
        let profile = try? JSONDecoder().decode(TrophyProfile.self, from: Data(
            #"{"trophyLevel":312,"progress":64,"tier":4,"earnedTrophies":{"bronze":1184,"silver":352,"gold":121,"platinum":27}}"#.utf8))
        TrophyStore.shared.usePreviewData(profile: profile, games: games, trophies: list, recent: [], nowPlaying: nil)
        let names = ["Dawnbreaker", "Silent Step", "Old Friends", "Iron Will", "Long Way Home", "Night Owl"]
        TrophyLibrary.shared.usePreviewData(games.prefix(6).enumerated().map { i, game in
            TrophyLibrary.Entry(game: game, trophies: (0..<25).map { n in
                let grade: TrophyGrade = n == 0 && game.progress == 100 ? .platinum : (n % 6 == 0 ? .gold : (n % 3 == 0 ? .silver : .bronze))
                return trophy(100 + i * 30 + n, names[(n + i) % names.count], "Detail", grade,
                              Double((n * 11 + i * 7) % 88) + 0.6, earned: ago(n * 9 + i * 4))
            })
        })
    }
}
