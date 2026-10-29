import SwiftUI

/// Rough platinum plan from the trophy texts alone. Sony gives no "missable" or "story" flags,
/// so this reads keywords (English and Turkish) and earn rates; it's a guess, and the page says so
/// and links to real guides.
enum Route {
    enum Phase: Int, CaseIterable {
        case missable, story, cleanup, grind, difficulty, online

        var title: String {
            let tr = AppLanguage.current.resolved == .tr
            switch self {
            case .missable: return tr ? "Dikkat: kaçırılabilir olabilir" : "Careful: may be missable"
            case .story: return tr ? "Hikâye ile gelir" : "Comes with the story"
            case .cleanup: return tr ? "Toplanabilirler ve temizlik turu" : "Collectibles and cleanup"
            case .grind: return tr ? "Grind" : "Grind"
            case .difficulty: return tr ? "Zorluk" : "Difficulty"
            case .online: return tr ? "Çevrimiçi" : "Online"
            }
        }

        var hint: String {
            let tr = AppLanguage.current.resolved == .tr
            switch self {
            case .missable: return tr ? "Bölüme, seçime ya da bir ana bağlı görünüyor. Oynamadan önce rehbere bak." : "Looks tied to a chapter, a choice or a moment. Check a guide before playing."
            case .story: return tr ? "İlerledikçe kendiliğinden gelenler; en çok alınanlar." : "Unlock as you progress; the most common ones."
            case .cleanup: return tr ? "Hikâyeden sonra, bölüm seçerek toplanabilir." : "Best after the story, with chapter select."
            case .grind: return tr ? "Sayı biriktirmeli; arada yap." : "Counters to build up; chip away at them."
            case .difficulty: return tr ? "Zorluk ya da kısıtlama isteyen; en sona bırak." : "Need a difficulty or restriction; leave for last."
            case .online: return tr ? "Sunucular kapanmadan yap." : "Do these before servers shut down."
            }
        }

        var icon: String {
            switch self {
            case .missable: return "exclamationmark.triangle.fill"
            case .story: return "book.fill"
            case .cleanup: return "sparkle.magnifyingglass"
            case .grind: return "arrow.triangle.2.circlepath"
            case .difficulty: return "flame.fill"
            case .online: return "globe"
            }
        }

        var color: Color {
            switch self {
            case .missable: return .orange
            case .story: return Style.glow
            case .cleanup: return TrophyGrade.gold.color
            case .grind: return .purple
            case .difficulty: return .red
            case .online: return .blue
            }
        }
    }

    private static let words: [(Phase, [String])] = [
        (.online, ["online", "multiplayer", "ranked", "co-op", "coop", "çevrimiçi", "çok oyunculu", "eşleşme"]),
        (.difficulty, ["hard difficulty", "on hard", "grounded", "lethal", "nightmare", "survivor", "without dying", "without taking damage",
                       "no damage", "permadeath", "zor ", "zorlukta", "ölmeden", "hasar almadan", "kabus"]),
        (.missable, ["before", "without being", "during chapter", "in chapter", "choose", "chose", "decide", "spare", "save the",
                     "don't", "do not", "never", "within", "önce", "sırasında", "bölümde", "seç", "karar", "bağışla", "kurtar", "asla", "olmadan"]),
        (.cleanup, ["all collectibles", "collect all", "find all", "every ", "all the ", "100%", "topla", "tümünü", "hepsini", "bütün"]),
        (.grind, ["times", "kill 1", "kill 5", "reach level", "earn ", "total of", "kez", "seviyeye ulaş", "toplam"]),
    ]

    static func phase(of trophy: Trophy) -> Phase {
        let text = (trophy.name + " " + trophy.detail).lowercased()
        for (phase, list) in words where list.contains(where: text.contains) {
            // A chapter-ending trophy most people got is story, even if it says "complete chapter".
            if phase == .missable, (trophy.earnedRate ?? 0) > 60 { return .story }
            return phase
        }
        if text.contains("chapter") || text.contains("bölüm") || text.contains("complete") || text.contains("tamamla")
            || (trophy.earnedRate ?? 0) > 40 { return .story }
        return trophy.grade == .platinum ? .cleanup : .grind
    }

    static func plan(_ trophies: [Trophy]) -> [(phase: Phase, trophies: [Trophy])] {
        let missing = trophies.filter { !$0.earned && $0.grade != .platinum }
        let grouped = Dictionary(grouping: missing, by: phase)
        return Phase.allCases.compactMap { phase in
            grouped[phase].map { (phase: phase, trophies: $0.sorted { ($0.earnedRate ?? 0) > ($1.earnedRate ?? 0) }) }
        }
    }
}

struct RouteView: View {
    let game: TrophyGame
    let trophies: [Trophy]
    @State private var selected: Trophy?

    var body: some View {
        let plan = Route.plan(trophies)
        GlassList {
            Section {
                Text(M.routeIntro).font(.footnote).foregroundStyle(.secondary)
                Link(destination: URL(string: "https://www.powerpyx.com/?s=\(game.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")+trophy+guide")!) {
                    Label(M.routeGuide, systemImage: "book")
                }
            }
            ForEach(Array(plan.enumerated()), id: \.offset) { index, step in
                Section {
                    ForEach(step.trophies) { trophy in
                        Button { selected = trophy } label: { TrophyRow(trophy: trophy, subtitle: trophy.detail) }
                            .tint(.primary)
                            .trophyActions(trophy, in: game, canMark: !Connectivity.shared.online)
                    }
                } header: {
                    Label("\(index + 1). \(step.phase.title) · \(step.trophies.count)", systemImage: step.phase.icon)
                        .foregroundStyle(step.phase.color)
                } footer: {
                    Text(step.phase.hint)
                }
            }
        }
        .compactSections()
        .navigationTitle(M.route)
        .inlineTitle()
        .sheet(item: $selected) { TrophySheet(trophy: $0, game: game, canMark: !Connectivity.shared.online) }
    }
}
