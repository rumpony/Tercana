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
