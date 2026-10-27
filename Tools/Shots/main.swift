// Store-quality screenshots with made-up data: every screen in a macOS-style window, plus a game
// scene with a translated subtitle. Fictional games and generated art only. Run Tools/Shots/run.sh.
import AppKit
import SwiftUI

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
UserDefaults.standard.set(CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "en", forKey: AppLanguage.defaultsKey)

// MARK: Generated artwork

func art(_ seed: Int, _ glyph: String, size: CGFloat = 256) -> NSImage {
    let palettes: [(NSColor, NSColor)] = [
        (.systemIndigo, .systemTeal), (.systemRed, .systemOrange), (.systemPurple, .systemPink),
        (.systemBlue, .systemCyan), (.systemGreen, .systemYellow), (.systemBrown, .systemOrange),
        (.systemTeal, .systemGreen), (.systemPink, .systemPurple),
    ]
    let (a, b) = palettes[seed % palettes.count]
    return NSImage(size: CGSize(width: size, height: size), flipped: false) { r in
        NSGradient(starting: a.blended(withFraction: 0.25, of: .black)!, ending: b)!.draw(in: r, angle: -55)
        NSColor.white.withAlphaComponent(0.10).setFill()
        NSBezierPath(ovalIn: CGRect(x: r.width * 0.45, y: r.height * 0.35, width: r.width * 0.8, height: r.width * 0.8)).fill()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size * 0.42, weight: .heavy),
            .foregroundColor: NSColor.white.withAlphaComponent(0.92),
        ]
        let text = glyph as NSString
        let t = text.size(withAttributes: attrs)
        text.draw(at: CGPoint(x: (r.width - t.width) / 2, y: (r.height - t.height) / 2), withAttributes: attrs)
        return true
    }
}

func badge(_ seed: Int) -> NSImage {
    NSImage(size: CGSize(width: 128, height: 128), flipped: false) { r in
        let colors: [NSColor] = [.systemOrange, .systemPurple, .systemBlue, .systemTeal, .systemPink, .systemGreen]
        NSGradient(starting: colors[seed % colors.count], ending: colors[(seed + 2) % colors.count])!.draw(in: r, angle: -60)
        let star = NSImage(systemSymbolName: ["star.fill", "bolt.fill", "flame.fill", "crown.fill", "leaf.fill", "moon.stars.fill"][seed % 6],
                           accessibilityDescription: nil)!
        let cfg = NSImage.SymbolConfiguration(pointSize: 56, weight: .bold).applying(.init(paletteColors: [.white]))
        star.withSymbolConfiguration(cfg)!.draw(in: r.insetBy(dx: 34, dy: 34))
        return true
    }
}

func url(_ s: String) -> URL { URL(string: "https://example.invalid/\(s)")! }

// MARK: Mock data

func counts(_ p: Int, _ g: Int, _ s: Int, _ b: Int) -> TrophyCounts { TrophyCounts(bronze: b, silver: s, gold: g, platinum: p) }
let titles = [
    ("Shadows of Velmora", 62), ("Neon Drift", 97), ("The Last Lighthouse", 100), ("Kingdom of Ash", 88),
    ("Starfall Odyssey", 45), ("Paper Garden", 100), ("Iron Hollow", 23), ("Echoes of Tarsis", 74),
    ("Crimson Circuit", 91), ("Moonlit Harbor", 12), ("Frostbound", 57), ("Wildroot", 100),
]
var games: [TrophyGame] = []
for (i, (name, progress)) in titles.enumerated() {
    let glyph = String(name.split(separator: " ").map { $0.first! }.prefix(2))
    let u = url("game\(i).png")
    RemoteIcon.preloaded[u] = art(i, glyph)
    let done = progress == 100
    games.append(TrophyGame(npServiceName: "trophy2", npCommunicationId: "G\(i)", trophyTitleName: name,
        trophyTitleIconUrl: u.absoluteString, trophyTitlePlatform: i % 3 == 0 ? "PS5,PSPC" : "PS5",
        definedTrophies: counts(1, 6, 12, 28), earnedTrophies: counts(done || progress > 95 ? 1 : 0, progress / 18, progress / 9, progress / 4),
        progress: progress, lastUpdatedDateTime: "2026-10-\(20 - i)T20:00:00Z"))
}
func ago(_ d: Int, _ h: Int = 21) -> Date { Calendar.current.date(byAdding: .hour, value: -(d * 24 + (24 - h)), to: Date())! }
func trophy(_ id: Int, _ name: String, _ detail: String, _ g: TrophyGrade, _ rate: Double, earned: Date? = nil,
            hidden: Bool = false, progress: (String, String)? = nil) -> Trophy {
    let u = url("t\(id).png"); RemoteIcon.preloaded[u] = badge(id)
    var t = Trophy(id: id, name: name, detail: detail, grade: g, hidden: hidden, iconURL: u, groupId: "default")
    t.earned = earned != nil; t.earnedDate = earned; t.earnedRate = rate; t.rarity = TrophyRarity(rate: rate)
    t.progress = progress?.0; t.progressTarget = progress?.1
    return t
}
let gameTrophies = [
    trophy(1, "Lightkeeper", "Restore every lighthouse along the northern coast.", .gold, 8.4, progress: ("5", "7")),
    trophy(2, "Silent Tide", "Cross the harbor without being spotted.", .silver, 21.6),
    trophy(3, "Velmora's Heir", "Collect all other trophies.", .platinum, 3.2),
    trophy(4, "Hidden Ending", "Secret.", .gold, 1.1, hidden: true),
    trophy(5, "First Light", "Complete the prologue.", .bronze, 94.0, earned: ago(9)),
    trophy(6, "Cartographer", "Uncover the whole map.", .silver, 34.7, earned: ago(3)),
]
let profile = try! JSONDecoder().decode(TrophyProfile.self, from: Data(
    #"{"trophyLevel":312,"progress":64,"tier":4,"earnedTrophies":{"bronze":1184,"silver":352,"gold":121,"platinum":27}}"#.utf8))
var entries: [TrophyLibrary.Entry] = []
for (i, g) in games.prefix(8).enumerated() {
    var list: [Trophy] = []
    for n in 0..<30 {
        let grade: TrophyGrade = n == 0 && g.progress == 100 ? .platinum : (n % 6 == 0 ? .gold : (n % 3 == 0 ? .silver : .bronze))
        let rate = Double((n * 11 + i * 7) % 88) + 0.6
        let names = ["Dawnbreaker", "Silent Step", "Old Friends", "Iron Will", "Long Way Home", "Night Owl",
                     "Collector", "Sharpshooter", "Master Key", "Wanderer", "Untouchable", "Storyteller"]
        list.append(trophy(100 + i * 30 + n, names[(n + i) % names.count], "Detail", grade, rate, earned: ago(n * 9 + i * 4, (n * 7 + 18) % 24)))
    }
    entries.append(TrophyLibrary.Entry(game: g, trophies: list))
}

// MARK: Window chrome

struct Window<Content: View>: View {
    let title: String
    let content: Content
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 8) {
                    Circle().fill(Color(red: 1, green: 0.37, blue: 0.34))
                    Circle().fill(Color(red: 1, green: 0.74, blue: 0.18))
                    Circle().fill(Color(red: 0.16, green: 0.79, blue: 0.25))
                    Spacer()
                }
                .frame(height: 12).padding(.leading, 18)
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            }
            .frame(height: 38)
            .background(Color(nsColor: .windowBackgroundColor))
            Divider()
            content.background(Color(nsColor: .windowBackgroundColor))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.12)))
        .shadow(color: .black.opacity(0.25), radius: 30, y: 14)
        .padding(60)
        .background(LinearGradient(colors: [Color(red: 0.06, green: 0.33, blue: 0.38), Color(red: 0.09, green: 0.12, blue: 0.28)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}

struct GameScene: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color(red: 0.10, green: 0.12, blue: 0.24), Color(red: 0.42, green: 0.30, blue: 0.42),
                                    Color(red: 0.90, green: 0.58, blue: 0.38)], startPoint: .top, endPoint: .bottom)
            ForEach(0..<40, id: \.self) { i in
                Circle().fill(.white.opacity(0.6)).frame(width: 2.5)
                    .offset(x: CGFloat((i * 7919 + 13) % 1560) - 780, y: -CGFloat(300 + (i * i * 37 + i * 101) % 520))
            }
            Circle().fill(Color(red: 1, green: 0.84, blue: 0.6)).frame(width: 130).blur(radius: 1).offset(x: 420, y: -330)
            Mountains(heights: [0.55, 0.35, 0.62, 0.42, 0.7, 0.38, 0.5], color: Color(red: 0.30, green: 0.22, blue: 0.32)).frame(height: 420)
            Mountains(heights: [0.3, 0.5, 0.25, 0.45, 0.3, 0.55, 0.28], color: Color(red: 0.15, green: 0.11, blue: 0.17)).frame(height: 300)
            HStack(alignment: .bottom, spacing: 26) { Figure(height: 150); Figure(height: 138) }
                .offset(x: 300, y: -118)
            SubtitleView(text: "ENZO: Kilitli... Tabii ki. Başka bir yol bulmalıyız.", dimmed: false, fontSize: 32,
                         width: 860, minHeight: 0, background: 0.55)
                .padding(.bottom, 64)
        }
        .frame(width: 1600, height: 900)
        .clipped()
    }
}

struct Mountains: View {
    let heights: [CGFloat]
    let color: Color
    var body: some View {
        GeometryReader { g in
            Path { p in
                let step = g.size.width / CGFloat(heights.count - 1)
                p.move(to: CGPoint(x: 0, y: g.size.height))
                for (i, h) in heights.enumerated() { p.addLine(to: CGPoint(x: CGFloat(i) * step, y: g.size.height * (1 - h))) }
                p.addLine(to: CGPoint(x: g.size.width, y: g.size.height))
            }
            .fill(color)
        }
    }
}

struct Figure: View {
    let height: CGFloat
    var body: some View {
        VStack(spacing: 4) {
            Circle().frame(width: height * 0.2)
            UnevenRoundedRectangle(topLeadingRadius: height * 0.12, topTrailingRadius: height * 0.12)
                .frame(width: height * 0.32, height: height * 0.72)
        }
        .foregroundStyle(Color(red: 0.06, green: 0.05, blue: 0.08))
    }
}

// MARK: Rendering

@MainActor func render<V: View>(_ name: String, _ size: CGSize, _ view: V) {
    let host = NSHostingView(rootView: view.environment(\.locale, S.locale).environment(\.controlActiveState, .key))
    let window = NSWindow(contentRect: CGRect(x: -30000, y: -30000, width: size.width, height: size.height),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .aqua)
    window.contentView = host
    host.frame = CGRect(origin: .zero, size: size)
    for _ in 0..<15 { RunLoop.main.run(until: Date().addingTimeInterval(0.1)); host.layoutSubtreeIfNeeded() }
    let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
    host.cacheDisplay(in: host.bounds, to: rep)
    try? rep.representation(using: .png, properties: [:])?.write(to: out.appendingPathComponent("\(name).png"))
    window.close()
    print("shot \(name)")
}

@MainActor func run() async {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.prohibited)
    let store = TrophyStore.shared
    store.usePreviewData(profile: profile, games: games, trophies: gameTrophies,
                         recent: entries.flatMap { e in e.trophies.prefix(4).map { TrophyStore.Earned(trophy: $0, game: e.game) } }
                            .sorted { $0.trophy.earnedDate! > $1.trophy.earnedDate! },
                         nowPlaying: "Shadows of Velmora")
    TrophyLibrary.shared.usePreviewData(entries)
    TrophyTargets.shared.toggle(gameTrophies[0], in: games[0])
    TrophyTargets.shared.setNote("Missable — last lighthouse is in chapter 6", for: gameTrophies[0], in: games[0])
    for (i, t) in entries[2].trophies.prefix(4).enumerated() where i < 4 { TrophyShowcase.shared.toggle(t, in: entries[2].game) }
    SubtitleLog.shared.clear()
    for (o, t) in [("MARA: We leave at first light.", "MARA: Şafakta yola çıkıyoruz."),
                   ("ENZO: Locked... Of course.", "ENZO: Kilitli... Tabii ki."),
                   ("MARA: Then we find another way in.", "MARA: O zaman başka bir giriş buluruz.")] {
        SubtitleLog.shared.add(original: o, translation: t)
    }

    let window = CGSize(width: 1400, height: 900)
    let canvas = CGSize(width: window.width + 120, height: window.height + 38 + 120)
    func shot<V: View>(_ name: String, _ title: String, _ view: V) {
        render(name, canvas, Window(title: title, content: view.frame(width: window.width, height: window.height)))
    }
    let router = HomeRouter()
    router.tab = .home; shot("1-home", "Tercana", HomeView(router: router))
    for (name, page) in [("2-trophies-profile", TrophyStore.Page.profile), ("3-trophies-game", .game("G0")),
                         ("4-trophies-stats", .stats), ("5-trophies-closest", .closest), ("6-trophies-recent", .recent)] {
        await store.open(page)
        let r = HomeRouter(); r.tab = .trophies
        shot(name, "Tercana", HomeView(router: r))
    }
    let h = HomeRouter(); h.tab = .history; shot("7-history", "Tercana", HomeView(router: h))
    let s = HomeRouter(); s.tab = .settings; shot("8-settings", "Tercana", HomeView(router: s))
    render("0-game", CGSize(width: 1600, height: 900), GameScene())
    exit(0)
}

Task { await run() }
RunLoop.main.run()
