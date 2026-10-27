// Local UI preview: renders Tercana screens with made-up data into PNGs, off screen.
// No network, no PSN account, nothing appears on the desktop. Run with Tools/Preview/run.sh.
import AppKit
import SwiftUI

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "preview-out")
let assets = URL(fileURLWithPath: CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Tools/Preview/assets")
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let icon = assets.appendingPathComponent("game.png").absoluteString

// MARK: Mock data

func counts(_ p: Int, _ g: Int, _ s: Int, _ b: Int) -> TrophyCounts {
    TrophyCounts(bronze: b, silver: s, gold: g, platinum: p)
}

func game(_ id: String, _ name: String, _ progress: Int, earned: TrophyCounts, defined: TrophyCounts,
          platform: String = "PS5", updated: String = "2026-10-20T10:00:00Z") -> TrophyGame {
    TrophyGame(npServiceName: "trophy2", npCommunicationId: id, trophyTitleName: name, trophyTitleIconUrl: icon,
               trophyTitlePlatform: platform, definedTrophies: defined, earnedTrophies: earned,
               progress: progress, lastUpdatedDateTime: updated)
}

let games: [TrophyGame] = [
    game("G1", "Mafia: The Old Country", 12, earned: counts(0, 1, 2, 9), defined: counts(1, 6, 10, 30)),
    game("G2", "Assassin's Creed® Mirage — Extremely Long Edition Name For Wrapping", 85,
         earned: counts(0, 5, 9, 30), defined: counts(1, 6, 10, 34)),
    game("G3", "Marvel's Spider-Man 2", 97, earned: counts(1, 8, 12, 29), defined: counts(1, 8, 12, 30), platform: "PS5,PSPC"),
    game("G4", "ASTRO BOT", 100, earned: counts(1, 9, 11, 24), defined: counts(1, 9, 11, 24)),
    game("G5", "VALORANT", 18, earned: counts(0, 0, 2, 4), defined: counts(0, 3, 9, 20)),
    game("G6", "ELDEN RING™", 3, earned: counts(0, 0, 0, 2), defined: counts(1, 7, 9, 25)),
] + (7...40).map { i in
    game("G\(i)", "Game \(i)", i * 2 % 100, earned: counts(0, 1, 1, 3), defined: counts(1, 4, 8, 20))
}

let calendar = Calendar.current
func daysAgo(_ d: Int, hour: Int = 21) -> Date {
    calendar.date(bySettingHour: hour, minute: 15, second: 0, of: calendar.date(byAdding: .day, value: -d, to: Date())!)!
}

func trophy(_ id: Int, _ name: String, _ detail: String, _ grade: TrophyGrade, rate: Double, earned: Date? = nil,
            hidden: Bool = false, progress: (String, String)? = nil) -> Trophy {
    var t = Trophy(id: id, name: name, detail: detail, grade: grade, hidden: hidden, iconURL: URL(string: icon), groupId: "default")
    t.earned = earned != nil
    t.earnedDate = earned
    t.earnedRate = rate
    t.rarity = TrophyRarity(rate: rate)
    t.progress = progress?.0
    t.progressTarget = progress?.1
    return t
}

let trophies: [Trophy] = [
    trophy(0, "Made Man", "Collect all other trophies.", .platinum, rate: 3.1),
    trophy(1, "Impeccable Timing", "Complete a timer level with only a fraction of a second to spare.", .gold, rate: 10.7),
    trophy(2, "Family Business", "Finish chapter 3 without being spotted by the guards in the mine.", .silver, rate: 22.4,
           earned: daysAgo(2)),
    trophy(3, "Secret Ending", "Hidden description that should be blurred.", .gold, rate: 1.2, hidden: true),
    trophy(4, "Collector", "Find all 50 tarot cards.", .bronze, rate: 41.0, progress: ("17", "50")),
    trophy(5, "First Steps", "Complete the prologue.", .bronze, rate: 92.5, earned: daysAgo(30)),
]

let profileJSON = #"{"trophyLevel":224,"progress":70,"tier":3,"earnedTrophies":{"bronze":657,"silver":206,"gold":68,"platinum":13}}"#
let profile = try! JSONDecoder().decode(TrophyProfile.self, from: Data(profileJSON.utf8))

// A year of earned trophies across games, for the statistics page.
var entries: [TrophyLibrary.Entry] = []
for (index, g) in games.prefix(6).enumerated() {
    var list: [Trophy] = []
    for n in 0..<25 {
        let rate = Double((n * 7 + index * 3) % 90) + 0.4
        list.append(trophy(n, "\(g.name) #\(n)", "Detail", n == 0 && index < 3 ? .platinum : (n % 5 == 0 ? .gold : .bronze),
                           rate: rate, earned: daysAgo(n * 13 + index * 5, hour: (n * 5) % 24)))
    }
    entries.append(TrophyLibrary.Entry(game: g, trophies: list))
}

// MARK: Rendering

var failures: [String] = []

@MainActor
func render<V: View>(_ name: String, width: CGFloat, height: CGFloat, dark: Bool = false, _ view: V) {
    let window = NSWindow(contentRect: CGRect(x: -20000, y: -20000, width: width, height: height),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    // Off-screen captures skip the window's own background, so paint it into the view.
    let host = NSHostingView(rootView: view
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.locale, S.locale))
    window.contentView = host
    host.frame = CGRect(x: 0, y: 0, width: width, height: height)
    // Let SwiftUI lay out, run tasks and load local images.
    for _ in 0..<12 {
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        host.layoutSubtreeIfNeeded()
    }
    // Layout check: content that needs more room than the window has gets clipped or pushed off-centre.
    // Ask how wide the content ends up when offered exactly this width. Truncating text and
    // wrapping grids fit; fixed rows that can't shrink report more than they were given.
    let measurer = NSHostingController(rootView: view.environment(\.locale, S.locale))
    let needed = measurer.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
    // Width only: pages scroll vertically, but anything wider than the window is cut off.
    if needed.width > width + 1 {
        failures.append("\(name): needs \(Int(needed.width))×\(Int(needed.height)), window is \(Int(width))×\(Int(height))")
    }
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
    host.cacheDisplay(in: host.bounds, to: rep)
    try? rep.representation(using: .png, properties: [:])?.write(to: output.appendingPathComponent("\(name).png"))
    window.close()
    print("rendered \(name)")
}

@MainActor
func run() async {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.prohibited)
    // Canary: a row that can't shrink must be reported, or the layout check itself is broken.
    render("canary", width: 400, height: 100, HStack { Text("fixed").frame(width: 600) })
    guard failures.count == 1 else { print("LAYOUT CHECK BROKEN: canary not caught"); exit(2) }
    failures.removeAll()
    let languages = CommandLine.arguments.count > 3 ? CommandLine.arguments[3].split(separator: ",").map(String.init) : ["tr"]
    for language in languages {
        UserDefaults.standard.set(language, forKey: AppLanguage.defaultsKey)
        let store = TrophyStore.shared
        store.usePreviewData(profile: profile, games: games, trophies: trophies,
                             recent: entries.flatMap { e in e.trophies.prefix(3).map { TrophyStore.Earned(trophy: $0, game: e.game) } },
                             nowPlaying: "Mafia: The Old Country")
        TrophyLibrary.shared.usePreviewData(entries)
        TrophyTargets.shared.toggle(trophies[1], in: games[0])
        TrophyTargets.shared.setNote("Bölüm 3'te kaçırılabilir", for: trophies[1], in: games[0])

        let pages: [(String, TrophyStore.Page)] = [
            ("profile", .profile), ("stats", .stats), ("closest", .closest), ("recent", .recent),
            ("platinums", .platinums), ("targets", .targets), ("game", .game("G1")),
        ]
        for (name, page) in pages {
            await store.open(page)
            render("\(language)-trophies-\(name)", width: 1100, height: 720, TrophiesView())
            render("\(language)-trophies-\(name)-min", width: 1040, height: 620, TrophiesView())
        }
        await store.open(.game("G1"))
        render("\(language)-trophies-game-min", width: 1040, height: 600, TrophiesView())
        render("\(language)-trophies-game-dark", width: 1100, height: 720, dark: true, TrophiesView())
        TrophyLibrary.shared.usePreviewData([])
        await store.open(.stats)
        render("\(language)-trophies-stats-empty", width: 1100, height: 720, TrophiesView())
        TrophyLibrary.shared.usePreviewData(entries)
        render("\(language)-settings", width: 900, height: 900, SettingsView())

        SubtitleLog.shared.clear()
        SubtitleLog.shared.add(original: "GAETANO: Read this again for me, will you?", translation: "GAETANO: Bunu bana tekrar okur musun?")
        SubtitleLog.shared.add(original: "ENZO: \"Dearest nephew,", translation: "ENZO: \"Sevgili yeğenim,")
        render("\(language)-subtitle-log", width: 520, height: 400, SubtitleLogView())
        render("\(language)-subtitle", width: 900, height: 80,
               SubtitleView(text: "GAETANO: Bunu bana tekrar okur musun?", dimmed: false, fontSize: 22, width: 900,
                            minHeight: 0, background: 0.55).background(Color(red: 0.75, green: 0.68, blue: 0.5)))
        for tab in HomeView.Tab.allCases {
            let router = HomeRouter()
            router.tab = tab
            for (label, w, h) in [("min", 1040.0, 660.0), ("default", 1040.0, 720.0)] {
                render("\(language)-home-\(tab.rawValue)-\(label)", width: w, height: h, HomeView(router: router))
            }
        }
        render("\(language)-psn-signin", width: 900, height: 600, SignInView(store: TrophyStore.shared))
        render("\(language)-prompt", width: 760, height: 120,
               PromptView(message: S.remotePlayPrompt, hint: S.remotePlayPromptHint,
                          actions: [(S.start, true, {}), (S.chooseArea, false, {})], onClose: {}).padding(20))
        render("\(language)-result-card", width: 400, height: 260,
               ResultView(original: "Dear Enzo, I hope this message reaches you in good health.",
                          translation: "Sevgili Enzo, umarım bu mesaj sana sağlıkla ulaşır.", error: nil, onClose: {}))
        TrophyTargets.shared.toggle(trophies[1], in: games[0])
    }
    if failures.isEmpty {
        print("LAYOUT OK")
        exit(0)
    }
    print("LAYOUT FAILURES:")
    failures.forEach { print("  ✗ \($0)") }
    exit(1)
}

Task { await run() }
RunLoop.main.run()
