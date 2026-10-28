import Foundation

/// Strings that exist only in the phone app. Turkish, otherwise English.
enum M {
    private static var tr: Bool { AppLanguage.current.resolved == .tr }
    private static func t(_ tr: String, _ en: String) -> String { Self.tr ? tr : en }

    static var profileTab: String { t("Profil", "Profile") }
    static var gamesTab: String { t("Oyunlar", "Games") }
    static var targetsTab: String { t("Hedefler", "Targets") }
    static var statsTab: String { t("İstatistik", "Stats") }
    static var points: String { t("Kupa puanı", "Trophy points") }
    static var levelPlanner: String { t("Seviye hesaplayıcı", "Level planner") }
    static func targetLevel(_ n: Int) -> String { t("Hedef seviye \(n)", "Target level \(n)") }
    static func pointsLeft(_ n: Int) -> String { t("\(n.formatted()) puan kaldı", "\(n.formatted()) points to go") }
    static func roughly(gold: Int, bronze: Int, plats: Int) -> String {
        t("≈ \(plats) platin · \(gold) altın · \(bronze) bronz", "≈ \(plats) platinum · \(gold) gold · \(bronze) bronze")
    }
    static var all: String { t("Hepsi", "All") }
    static var close: String { t("Bitmeye yakın", "Almost done") }
    static var plats: String { t("Platinler", "Platinums") }
    static var recentOnes: String { t("Son kupalar", "Recent trophies") }
    static var account: String { t("Hesap", "Account") }
    static var language: String { t("Dil", "Language") }
    static var syncLibrary: String { t("Kütüphaneyi eşitle", "Sync library") }
    static var note: String { t("Not", "Note") }
    static var details: String { t("Ayrıntılar", "Details") }
    static var signInHint: String {
        t("Kupaların PlayStation Network'ten okunur. Sadece okuma yapılır, hiçbir şey değiştirilmez.",
          "Your trophies are read from PlayStation Network. Read-only; nothing is changed.")
    }
    static var signInFailed: String { t("Giriş tamamlanamadı, tekrar dene.", "Sign-in didn't complete, try again.") }
    static var cancel: String { t("Vazgeç", "Cancel") }
    static var points15: String { t("Bronz 15 · Gümüş 30 · Altın 90 · Platin 300 puan", "Bronze 15 · Silver 30 · Gold 90 · Platinum 300 points") }
}

extension Date {
    /// Date in the interface language rather than the phone's region.
    func shown(time: Bool = false) -> String {
        formatted(Date.FormatStyle(date: .abbreviated, time: time ? .shortened : .omitted).locale(S.locale))
    }
}

extension M {
    static var friendsTab: String { t("Arkadaşlar", "Friends") }
    static var searchPlayer: String { t("PSN kimliği ara", "Search PSN ID") }
    static var privateProfile: String { t("Bu oyuncunun kupaları gizli.", "This player's trophies are private.") }
    static var notFound: String { t("Oyuncu bulunamadı.", "Player not found.") }
    static var noFriends: String { t("Arkadaş listesi boş ya da gizli.", "Friend list is empty or private.") }
    static var compare: String { t("Karşılaştır", "Compare") }
    static var commonGames: String { t("Ortak oyunlar", "Games in common") }
    static var you: String { t("Sen", "You") }
    static var hunting: String { t("Avlanıyor", "Hunting") }
    static var startHunting: String { t("Av listesine ekle", "Add to hunt list") }
    static var stopHunting: String { t("Av listesinden çıkar", "Remove from hunt list") }
    static var sortBy: String { t("Sırala", "Sort") }
    static var sortRecent: String { t("Son oynanan", "Last played") }
    static var sortProgress: String { t("İlerleme", "Progress") }
    static var sortName: String { t("Ad", "Name") }
    static var platform: String { t("Platform", "Platform") }
    static var allPlatforms: String { t("Tüm platformlar", "All platforms") }
    static var share: String { t("Paylaş", "Share") }
    static var shareCard: String { t("Profil kartını paylaş", "Share profile card") }
    static var heatmap: String { t("Kupa takvimi", "Trophy calendar") }
    static var onThisDay: String { t("Geçmişte bugün", "On this day") }
    static func yearsAgo(_ n: Int) -> String { t("\(n) yıl önce", n == 1 ? "1 year ago" : "\(n) years ago") }
    static var platinumWall: String { t("Platin duvarı", "Platinum wall") }
    static var yearReview: String { t("Yıl özeti", "Year in review") }
    static var bestMonth: String { t("En iyi ay", "Best month") }
    static var nextUp: String { t("Sıradaki kolay kupalar", "Easiest next trophies") }
    static var nextUpHint: String { t("Başladığın oyunlarda en çok kişinin aldığı eksik kupalar.", "Missing trophies most players got, in games you've started.") }
    static var averageRarity: String { t("Ortalama nadirlik", "Average rarity") }
    static func platinumETA(_ days: Int) -> String { t("Bu tempoyla platin ≈ \(days) gün", "At this pace, platinum in ≈ \(days) days") }
    static var markDone: String { t("Yaptım olarak işaretle", "Mark as done") }
    static var unmarkDone: String { t("İşareti kaldır", "Unmark") }
    static var doneLocally: String { t("Kendi işaretin", "Your mark") }
    static var baseGame: String { t("Ana oyun", "Base game") }
    static func dlc(_ id: String) -> String { t("Ek paket \(id)", "DLC \(id)") }
    static var notifications: String { t("Bildirimler", "Notifications") }
    static var notifyNew: String { t("Yeni kupa bildirimi", "New trophy alerts") }
    static var notifyHint: String { t("Arka planda ara sıra kontrol eder; iOS ne zaman izin verirse.", "Checks now and then in the background, whenever iOS allows.") }
    static var newTrophy: String { t("Yeni kupa", "New trophy") }
    static var newPlatinum: String { t("Yeni platin!", "New platinum!") }
    static var theme: String { t("Renk", "Color") }
    static var level: String { t("Seviye", "Level") }
    static var levelUp: String { t("Seviye atladın!", "Level up!") }
    static func levelReached(_ n: Int) -> String { t("Kupa seviyen \(n) oldu.", "You reached trophy level \(n).") }
    static var notifyLevel: String { t("Seviye atlama", "Level ups") }
    static var notifyOnThisDay: String { t("Geçmişte bugün hatırlatması", "On this day reminder") }
    static var notifyWeekly: String { t("Haftalık özet (pazar akşamı)", "Weekly recap (Sunday evening)") }
    static func weekly(_ n: Int, _ p: Int) -> String { t("Bu hafta \(n) kupa, \(p) puan kazandın.", "This week: \(n) trophies, \(p) points.") }
    static var notifyHunting: String { t("Av listesi hatırlatması", "Hunt list nudges") }
    static func huntingNudge(_ game: String, _ left: Int) -> String { t("\(game): platine \(left) kupa kaldı. Bir tur daha?", "\(game): \(left) trophies left to platinum. One more session?") }
}

extension M {
    static var leaderboard: String { t("Sıralama", "Leaderboard") }
    static var friendsList: String { t("Arkadaşlar", "Friends") }
    static var refreshLeaderboard: String { t("Sıralamayı güncelle", "Update leaderboard") }
    static func refreshing(_ done: Int, _ total: Int) -> String { t("Güncelleniyor… \(done)/\(total)", "Updating… \(done)/\(total)") }
    static var leaderboardHint: String {
        t("Sen ve PSN arkadaşların, kupa puanına göre. Sadece bu butona bastığında güncellenir; arka planda hiçbir şey çalışmaz. Kupaları gizli olan arkadaşlar listede görünmez.",
          "You and your PSN friends by trophy points. Updates only when you tap the button; nothing runs in the background. Friends with private trophies aren't listed.")
    }
    static func yourRank(_ rank: Int, _ count: Int) -> String { t("\(count) kişi arasında \(rank). sıradasın", "You're #\(rank) of \(count)") }
    static var today: String { t("Bugün", "Today") }
    static var sinceYesterday: String { t("Dünden beri", "Since yesterday") }
    static func rankMove(_ n: Int) -> String { n > 0 ? "↑\(n)" : n < 0 ? "↓\(-n)" : "–" }
    static func pointsMove(_ n: Int) -> String { n > 0 ? "+\(n.formatted())" : "\(n.formatted())" }
    static var country: String { t("Ülke", "Country") }
    static func countryBoard(_ name: String) -> String { t("\(name) sıralamasını aç", "Open \(name) leaderboard") }
    static var myCountryRank: String { t("Ülkede ve dünyada kaçıncıyım?", "My country and world rank") }
    static var psnProfilesHint: String {
        t("Ülke ve dünya sıralamasını PSNProfiles tutuyor; sayfası uygulamanın içinde açılır. Profilin PSNProfiles'ta yoksa önce sitede bir kez aratıp ekletmen gerekir.",
          "Country and world ranks come from PSNProfiles; its page opens inside the app. If your profile isn't on PSNProfiles yet, search for it once on the site to add it.")
    }
    static var worldRank: String { t("Dünya sıralamamı PSNProfiles'ta aç", "Open my world rank on PSNProfiles") }
    static func updatedAt(_ s: String) -> String { t("Son güncelleme: \(s)", "Updated: \(s)") }
}
