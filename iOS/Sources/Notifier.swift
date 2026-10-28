import BackgroundTasks
import Foundation
import UserNotifications
import WidgetKit

/// Background checks that turn PSN changes into local notifications. iOS decides when the
/// refresh actually runs (usually every hour or few), so alerts are best-effort, not instant.
@MainActor
enum Notifier {
    static let taskID = "com.rumpony.TercanaMobile.refresh"

    enum Kind: String, CaseIterable {
        case newTrophy, level, onThisDay, weekly, hunting
        var key: String { "notify.\(rawValue)" }
        var title: String {
            switch self {
            case .newTrophy: return M.notifyNew
            case .level: return M.notifyLevel
            case .onThisDay: return M.notifyOnThisDay
            case .weekly: return M.notifyWeekly
            case .hunting: return M.notifyHunting
            }
        }
        var isOn: Bool { UserDefaults.standard.bool(forKey: key) }
    }

    private struct Seen: Codable {
        var earned: [String: Int] = [:]
        var platinums: Set<String> = []
        var level = 0
        var weekStart: Date?
        var weekPoints = 0
        var weekTrophies = 0
        var weeklySent: Date?
        var onThisDaySent: Date?
        var huntingSent: Date?
    }

    private static var seen: Seen {
        get { (UserDefaults.standard.data(forKey: "notifier.seen")).flatMap { try? JSONDecoder().decode(Seen.self, from: $0) } ?? Seen() }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: "notifier.seen") }
    }

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            let work = Task { @MainActor in
                await check(notify: true)
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = { work.cancel() }
            schedule()
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date().addingTimeInterval(45 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Compares PSN with what was seen last time. With `notify` false it only records the
    /// current state (used when the app opens, since the player sees the changes there).
    static func check(notify: Bool) async {
        guard PSNClient.hasStoredLogin, !Demo.isOn,
              let games = try? await PSNClient.shared.games() else { return }
        let profile = try? await PSNClient.shared.profile()
        var state = seen
        let first = state.earned.isEmpty

        if notify && !first && Kind.newTrophy.isOn {
            let changed = games.filter { $0.earnedTrophies.total > (state.earned[$0.id] ?? 0) }
            for game in changed.prefix(3) {
                let gained = game.earnedTrophies.total - (state.earned[game.id] ?? 0)
                if game.platinumEarned && !state.platinums.contains(game.id) {
                    post(M.newPlatinum, game.name, id: "plat-\(game.id)")
                } else if let list = try? await PSNClient.shared.trophies(for: game),
                          let newest = list.filter(\.earned).max(by: { ($0.earnedDate ?? .distantPast) < ($1.earnedDate ?? .distantPast) }) {
                    let more = gained > 1 ? " +\(gained - 1)" : ""
                    post("\(M.newTrophy) · \(newest.grade.label)", "\(newest.name)\(more) — \(game.name)", id: "new-\(game.id)")
                }
            }
        }
        if let level = profile?.level {
            if notify && state.level > 0 && level > state.level && Kind.level.isOn {
                post(M.levelUp, M.levelReached(level), id: "level-\(level)")
            }
            state.level = level
        }

        let points = profile.map { Level.points($0.earnedTrophies) } ?? 0
        let trophies = profile?.earnedTrophies.total ?? 0
        let calendar = Calendar.current
        let week = calendar.dateInterval(of: .weekOfYear, for: Date())?.start
        if state.weekStart != week {
            state.weekStart = week
            state.weekPoints = points
            state.weekTrophies = trophies
        }
        let now = Date()
        let evening = calendar.component(.hour, from: now) >= 19
        if notify && Kind.weekly.isOn && calendar.component(.weekday, from: now) == 1 && evening
            && !(state.weeklySent.map { calendar.isDate($0, inSameDayAs: now) } ?? false) && trophies > state.weekTrophies {
            post("Tercana", M.weekly(trophies - state.weekTrophies, points - state.weekPoints), id: "weekly")
            state.weeklySent = now
        }
        if notify && Kind.onThisDay.isOn && calendar.component(.hour, from: now) >= 10
            && !(state.onThisDaySent.map { calendar.isDate($0, inSameDayAs: now) } ?? false) {
            let earned = TrophyStats(TrophyLibrary.shared.entries).earned
            if let memory = Insights.onThisDay(earned).first(where: { $0.trophy.grade == .platinum }) ?? Insights.onThisDay(earned).first {
                let years = calendar.component(.year, from: now) - calendar.component(.year, from: memory.date)
                post("\(M.onThisDay) · \(M.yearsAgo(years))", "\(memory.trophy.name) — \(memory.game.name)", id: "otd")
            }
            state.onThisDaySent = now
        }
        if notify && Kind.hunting.isOn && evening
            && (state.huntingSent.map { now.timeIntervalSince($0) > 3 * 86_400 } ?? true),
           let game = Local.shared.hunting.lazy.compactMap({ id in games.first { $0.id == id } }).first(where: { !$0.platinumEarned }) {
            post(M.hunting, M.huntingNudge(game.name, game.definedTrophies.total - game.earnedTrophies.total), id: "hunt")
            state.huntingSent = now
        }

        updateWidget(profile: profile, games: games)
        state.earned = Dictionary(games.map { ($0.id, $0.earnedTrophies.total) }, uniquingKeysWith: { a, _ in a })
        state.platinums = Set(games.filter(\.platinumEarned).map(\.id))
        seen = state
    }

    static func updateWidget(profile: TrophyProfile?, games: [TrophyGame]) {
        guard let profile else { return }
        let c = profile.earnedTrophies
        let hunted = Local.shared.hunting.lazy.compactMap { id in games.first { $0.id == id } }.first
        WidgetData(level: profile.level, progress: profile.progress, counts: [c.platinum, c.gold, c.silver, c.bronze],
                   huntingName: hunted?.name, huntingProgress: hunted?.progress).save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func post(_ title: String, _ body: String, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}
