import Foundation

/// Interface languages. "system" follows macOS and falls back to English.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, tr, en, de, es, fr

    var id: String { rawValue }

    /// The language actually used for the interface.
    var resolved: AppLanguage {
        guard self == .system else { return self }
        for preferred in Locale.preferredLanguages {
            let code = Locale(identifier: preferred).language.languageCode?.identifier ?? ""
            if let match = AppLanguage(rawValue: code), match != .system { return match }
        }
        return .en
    }

    /// Each language shows its own name, so people can find theirs whatever is selected now.
    var nativeName: String {
        switch self {
        case .system: return S.systemLanguage
        case .tr: return "Türkçe"
        case .en: return "English"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .fr: return "Français"
        }
    }

    var locale: Locale { Locale(identifier: resolved.rawValue) }

    static let defaultsKey = "appLanguage"

    /// Read straight from UserDefaults so strings can be produced off the main actor (e.g. in errors).
    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .system
    }
}

/// Every user-facing string, in all interface languages.
/// Windows rebuild their content when `Preferences.appLanguage` changes, so switching needs no restart.
enum S {
    private static func pick(_ tr: String, _ en: String, _ de: String, _ es: String, _ fr: String) -> String {
        switch AppLanguage.current.resolved {
        case .tr: return tr
        case .de: return de
        case .es: return es
        case .fr: return fr
        case .en, .system: return en
        }
    }

    static var locale: Locale { AppLanguage.current.locale }

    /// "%42" in Turkish, "42 %" in German, "42%" in English…
    static func percent(_ fraction: Double, digits: Int = 0) -> String {
        fraction.formatted(.percent.precision(.fractionLength(digits)).locale(locale))
    }

    /// Name of a language in the current interface language, e.g. "Japonca" / "Japanese".
    static func languageName(_ code: String) -> String {
        locale.localizedString(forIdentifier: code)?.capitalized(with: locale) ?? code
    }

    // MARK: Menu
    static var startLive: String { pick("Canlı çeviriyi başlat", "Start Live Translation", "Live-Übersetzung starten", "Iniciar traducción en vivo", "Démarrer la traduction en direct") }
    static var stopLive: String { pick("Canlı çeviriyi durdur", "Stop Live Translation", "Live-Übersetzung beenden", "Detener traducción en vivo", "Arrêter la traduction en direct") }
    static var newLiveArea: String { pick("Canlı çeviri: yeni alan seç…", "Live Translation: Choose New Area…", "Live-Übersetzung: neuen Bereich wählen…", "Traducción en vivo: elegir nueva área…", "Traduction en direct : choisir une zone…") }
    static var translateArea: String { pick("Bir alanı çevir…", "Translate an Area…", "Bereich übersetzen…", "Traducir un área…", "Traduire une zone…") }
    static var subtitleLog: String { pick("Altyazı geçmişi", "Subtitle History", "Untertitelverlauf", "Historial de subtítulos", "Historique des sous-titres") }
    static var trophies: String { pick("Kupalar", "Trophies", "Trophäen", "Trofeos", "Trophées") }
    static var settings: String { pick("Ayarlar…", "Settings…", "Einstellungen…", "Ajustes…", "Réglages…") }
    static var quit: String { pick("Çık", "Quit", "Beenden", "Salir", "Quitter") }
    static var noController: String { pick("Kumanda bağlı değil", "No controller connected", "Kein Controller verbunden", "Ningún mando conectado", "Aucune manette connectée") }
    static var controller: String { pick("Kumanda", "Controller", "Controller", "Mando", "Manette") }

    // MARK: Live & area translation
    static var pickLiveArea: String { pick("Altyazı alanını sürükleyerek seç  ·  Esc: vazgeç", "Drag over the subtitle area  ·  Esc to cancel", "Untertitelbereich aufziehen  ·  Esc: abbrechen", "Arrastra sobre la zona de subtítulos  ·  Esc: cancelar", "Faites glisser sur la zone des sous-titres  ·  Échap : annuler") }
    static var pickTranslateArea: String { pick("Çevrilecek alanı seç  ·  Esc: vazgeç", "Drag over the text to translate  ·  Esc to cancel", "Zu übersetzenden Bereich aufziehen  ·  Esc: abbrechen", "Arrastra sobre el texto a traducir  ·  Esc: cancelar", "Faites glisser sur le texte à traduire  ·  Échap : annuler") }
    static var waitingForSubtitle: String { pick("Altyazı bekleniyor…", "Waiting for subtitles…", "Warte auf Untertitel…", "Esperando subtítulos…", "En attente de sous-titres…") }
    static var grantPermissionFirst: String { pick("Önce ekran kaydı izni ver, sonra tekrar dene.", "Allow screen recording first, then try again.", "Erlaube zuerst die Bildschirmaufnahme und versuche es erneut.", "Permite primero la grabación de pantalla y vuelve a intentarlo.", "Autorisez d'abord l'enregistrement de l'écran, puis réessayez.") }
    static var dragHandle: String { pick("SubLens · sürükle", "SubLens · drag", "SubLens · ziehen", "SubLens · arrastrar", "SubLens · glisser") }
    static var noTextFound: String { pick("Çevrilecek yazı bulunamadı.", "No text found to translate.", "Kein Text zum Übersetzen gefunden.", "No se encontró texto para traducir.", "Aucun texte à traduire.") }
    static var copy: String { pick("Kopyala", "Copy", "Kopieren", "Copiar", "Copier") }
    static var close: String { pick("Kapat", "Close", "Schließen", "Cerrar", "Fermer") }

    // MARK: Errors
    static var errorNoPermission: String { pick("Ekran kaydı izni yok. Sistem Ayarları → Gizlilik ve Güvenlik → Ekran Kaydı'ndan SubLens'i aç.", "Screen recording isn't allowed. Turn on SubLens in System Settings → Privacy & Security → Screen Recording.", "Bildschirmaufnahme ist nicht erlaubt. Aktiviere SubLens unter Systemeinstellungen → Datenschutz & Sicherheit → Bildschirmaufnahme.", "La grabación de pantalla no está permitida. Activa SubLens en Ajustes del Sistema → Privacidad y seguridad → Grabación de pantalla.", "L'enregistrement de l'écran n'est pas autorisé. Activez SubLens dans Réglages Système → Confidentialité et sécurité → Enregistrement de l'écran.") }
    static var errorNoDisplay: String { pick("Seçilen alanın bulunduğu ekran bulunamadı.", "The display with the selected area isn't available.", "Der Bildschirm mit dem gewählten Bereich ist nicht verfügbar.", "La pantalla del área seleccionada no está disponible.", "L'écran de la zone choisie n'est pas disponible.") }
    static var errorPackMissing: String { pick("Dil paketi yüklü değil. Ayarlar → Çeviri → \"Dil paketini indir\".", "The language pack isn't installed. Settings → Translation → \"Download Language Pack\".", "Das Sprachpaket ist nicht installiert. Einstellungen → Übersetzung → „Sprachpaket laden“.", "El paquete de idioma no está instalado. Ajustes → Traducción → «Descargar paquete».", "Le pack de langue n'est pas installé. Réglages → Traduction → « Télécharger le pack ».") }
    static var errorUnsupportedPair: String { pick("Bu dil çifti Apple Çeviri tarafından desteklenmiyor.", "Apple Translation doesn't support this language pair.", "Apple Übersetzen unterstützt dieses Sprachpaar nicht.", "Apple Traducir no admite este par de idiomas.", "Apple Traduction ne prend pas en charge cette paire de langues.") }

    // MARK: Subtitle history
    static var showOriginal: String { pick("Orijinali de göster", "Show original", "Original anzeigen", "Mostrar original", "Afficher l'original") }
    static var clear: String { pick("Temizle", "Clear", "Leeren", "Borrar", "Effacer") }
    static var noSubtitlesYet: String { pick("Henüz altyazı yok", "No subtitles yet", "Noch keine Untertitel", "Aún no hay subtítulos", "Pas encore de sous-titres") }
    static var noSubtitlesHint: String { pick("Canlı çeviri çalışırken çevrilen satırlar burada birikir.", "Lines translated during live translation collect here.", "Während der Live-Übersetzung übersetzte Zeilen erscheinen hier.", "Las líneas traducidas en vivo se acumulan aquí.", "Les lignes traduites en direct s'accumulent ici.") }

    // MARK: Controller
    static func batteryLow(_ level: Float) -> String {
        let value = percent(Double(level))
        return pick("Kumanda pili azaldı: \(value)", "Controller battery low: \(value)", "Controller-Akku schwach: \(value)", "Batería del mando baja: \(value)", "Batterie de la manette faible : \(value)")
    }

    // MARK: Settings
    static var settingsTitle: String { pick("SubLens Ayarları", "SubLens Settings", "SubLens-Einstellungen", "Ajustes de SubLens", "Réglages de SubLens") }
    static var general: String { pick("Genel", "General", "Allgemein", "General", "Général") }
    static var appLanguage: String { pick("Uygulama dili", "App language", "App-Sprache", "Idioma de la app", "Langue de l'app") }
    static var systemLanguage: String { pick("Sistem dili", "System language", "Systemsprache", "Idioma del sistema", "Langue du système") }
    static var launchAtLogin: String { pick("Mac açılınca başlat", "Open at login", "Beim Anmelden öffnen", "Abrir al iniciar sesión", "Ouvrir à la connexion") }
    static var translation: String { pick("Çeviri", "Translation", "Übersetzung", "Traducción", "Traduction") }
    static var subtitleLanguage: String { pick("Altyazı dili", "Subtitle language", "Untertitelsprache", "Idioma de los subtítulos", "Langue des sous-titres") }
    static var translateInto: String { pick("Çeviri dili", "Translate into", "Übersetzen in", "Traducir a", "Traduire en") }
    static var languagePack: String { pick("Dil paketi", "Language pack", "Sprachpaket", "Paquete de idioma", "Pack de langue") }
    static var ready: String { pick("Hazır", "Ready", "Bereit", "Listo", "Prêt") }
    static var downloadPack: String { pick("Dil paketini indir", "Download Language Pack", "Sprachpaket laden", "Descargar paquete", "Télécharger le pack") }
    static var pairUnsupported: String { pick("Bu dil çifti desteklenmiyor", "This pair isn't supported", "Dieses Sprachpaar wird nicht unterstützt", "Este par no es compatible", "Paire non prise en charge") }
    static var liveTranslation: String { pick("Canlı çeviri", "Live translation", "Live-Übersetzung", "Traducción en vivo", "Traduction en direct") }
    static var coverOriginal: String { pick("Çeviriyi orijinal altyazının üstüne yaz", "Cover the original subtitle with the translation", "Übersetzung über den Originaluntertitel legen", "Cubrir el subtítulo original con la traducción", "Recouvrir le sous-titre original par la traduction") }
    static var textSize: String { pick("Yazı boyutu", "Text size", "Textgröße", "Tamaño del texto", "Taille du texte") }
    static var followRemotePlay: String { pick("Remote Play açılınca otomatik başlat, kapanınca durdur", "Start with Remote Play, stop when it quits", "Mit Remote Play starten und beim Beenden stoppen", "Iniciar con Remote Play y detener al cerrarlo", "Démarrer avec Remote Play, arrêter à sa fermeture") }
    static var followRemotePlayHint: String { pick("Otomatik başlatma son seçtiğin altyazı alanını kullanır.", "Auto-start uses the subtitle area you chose last.", "Der Autostart nutzt den zuletzt gewählten Untertitelbereich.", "El inicio automático usa la última zona de subtítulos elegida.", "Le démarrage auto utilise la dernière zone de sous-titres choisie.") }
    static var batteryAlerts: String { pick("Pil azalınca uyar", "Warn when the battery is low", "Bei schwachem Akku warnen", "Avisar con batería baja", "Avertir quand la batterie est faible") }
    static var disconnectPSN: String { pick("PSN bağlantısını kaldır", "Disconnect PSN", "PSN trennen", "Desconectar PSN", "Déconnecter le PSN") }
    static var connectPSNHint: String { pick("PSN hesabını Kupalar penceresinden bağlayabilirsin.", "Connect your PSN account from the Trophies window.", "Verbinde dein PSN-Konto im Trophäen-Fenster.", "Conecta tu cuenta de PSN desde la ventana Trofeos.", "Connectez votre compte PSN depuis la fenêtre Trophées.") }
    static var shortcuts: String { pick("Kısayollar", "Shortcuts", "Tastenkürzel", "Atajos", "Raccourcis") }
    static var toggleLive: String { pick("Canlı çeviri aç/kapat", "Toggle live translation", "Live-Übersetzung ein/aus", "Activar/desactivar traducción en vivo", "Activer/désactiver la traduction en direct") }

    // MARK: Trophies
    static var connectPSN: String { pick("PSN hesabını bağla", "Connect your PSN account", "PSN-Konto verbinden", "Conecta tu cuenta de PSN", "Connectez votre compte PSN") }
    static var connectIntro: String { pick("Kupalarını görmek için PlayStation hesabının oturum anahtarı gerekiyor. Anahtar sadece bu Mac'in anahtar zincirinde saklanır; SubLens yalnızca okuma yapar.", "To show your trophies, SubLens needs your PlayStation session token. It stays in this Mac's keychain and is only used to read data.", "Für deine Trophäen braucht SubLens dein PlayStation-Sitzungstoken. Es bleibt im Schlüsselbund dieses Macs und wird nur zum Lesen verwendet.", "Para mostrar tus trofeos, SubLens necesita el token de sesión de PlayStation. Se guarda en el llavero de este Mac y solo se usa para leer datos.", "Pour afficher vos trophées, SubLens a besoin de votre jeton de session PlayStation. Il reste dans le trousseau de ce Mac et sert uniquement à lire des données.") }
    static var connectStep1: String { pick("Tarayıcıda playstation.com'a giriş yap.", "Sign in at playstation.com in your browser.", "Melde dich im Browser bei playstation.com an.", "Inicia sesión en playstation.com en tu navegador.", "Connectez-vous sur playstation.com dans votre navigateur.") }
    static var connectStep2: String { pick("Bu sayfayı aç ve \"npsso\" değerini kopyala:", "Open this page and copy the \"npsso\" value:", "Öffne diese Seite und kopiere den „npsso“-Wert:", "Abre esta página y copia el valor «npsso»:", "Ouvrez cette page et copiez la valeur « npsso » :") }
    static var connectStep3: String { pick("Değeri aşağıya yapıştır.", "Paste it below.", "Füge ihn unten ein.", "Pégalo abajo.", "Collez-la ci-dessous.") }
    static var openPage: String { pick("Sayfayı aç", "Open Page", "Seite öffnen", "Abrir página", "Ouvrir la page") }
    static var tokenPlaceholder: String { pick("npsso (64 karakter)", "npsso (64 characters)", "npsso (64 Zeichen)", "npsso (64 caracteres)", "npsso (64 caractères)") }
    static var connect: String { pick("Bağlan", "Connect", "Verbinden", "Conectar", "Connecter") }
    static var unofficialNote: String { pick("Not: Bu bağlantı Sony'nin resmi olmayan, mobil uygulamanın kullandığı arayüzünü kullanır. SubLens istekleri seyrek tutar.", "Note: this uses the unofficial interface behind Sony's mobile app. SubLens keeps requests infrequent.", "Hinweis: Dies nutzt die inoffizielle Schnittstelle der Sony-App. SubLens stellt nur selten Anfragen.", "Nota: usa la interfaz no oficial de la app móvil de Sony. SubLens hace pocas solicitudes.", "Remarque : ceci utilise l'interface non officielle de l'app mobile de Sony. SubLens limite ses requêtes.") }
    static var pickAGame: String { pick("Bir oyun seç", "Choose a game", "Wähle ein Spiel", "Elige un juego", "Choisissez un jeu") }
    static var nowPlaying: String { pick("Şu an oynuyorsun", "Now playing", "Du spielst gerade", "Jugando ahora", "En cours de jeu") }
    static func gamesCount(_ count: Int) -> String { pick("Oyunlar (\(count))", "Games (\(count))", "Spiele (\(count))", "Juegos (\(count))", "Jeux (\(count))") }
    static var searchGames: String { pick("Oyun ara", "Search games", "Spiele suchen", "Buscar juegos", "Rechercher un jeu") }
    static var refresh: String { pick("Yenile", "Refresh", "Aktualisieren", "Actualizar", "Actualiser") }
    static var guides: String { pick("Rehberler", "Guides", "Guides", "Guías", "Guides") }
    static var order: String { pick("Sıra", "Order", "Reihenfolge", "Orden", "Ordre") }
    static var translateDescriptions: String { pick("Açıklamaları çevir", "Translate descriptions", "Beschreibungen übersetzen", "Traducir descripciones", "Traduire les descriptions") }
    static var hiddenTrophy: String { pick("Gizli kupa", "Hidden trophy", "Versteckte Trophäe", "Trofeo oculto", "Trophée caché") }
    static var revealSpoiler: String { pick("Spoiler'ı göster", "Show spoiler", "Spoiler anzeigen", "Mostrar spoiler", "Afficher le spoiler") }
    static func earnedBy(_ rate: Double) -> String {
        let value = percent(rate / 100, digits: 1)
        return pick("Oyuncuların \(value)'i aldı", "\(value) of players have it", "\(value) der Spieler haben sie", "Lo tiene el \(value) de los jugadores", "\(value) des joueurs l'ont")
    }
    static func progress(_ current: String, _ target: String) -> String {
        pick("İlerleme \(current)/\(target)", "Progress \(current)/\(target)", "Fortschritt \(current)/\(target)", "Progreso \(current)/\(target)", "Progression \(current)/\(target)")
    }
    static var searchYouTube: String { pick("YouTube'da ara", "Search YouTube", "Auf YouTube suchen", "Buscar en YouTube", "Rechercher sur YouTube") }
    static var searchWebGuide: String { pick("Web'de rehber ara", "Search the web for a guide", "Im Web nach einem Guide suchen", "Buscar una guía en la web", "Chercher un guide sur le web") }
    static var howToGet: String { pick("Bu kupa nasıl alınır?", "How do I get this trophy?", "Wie bekomme ich diese Trophäe?", "¿Cómo consigo este trofeo?", "Comment obtenir ce trophée ?") }
    static var filterMissing: String { pick("Eksikler", "Missing", "Fehlend", "Pendientes", "Manquants") }
    static var filterAll: String { pick("Tümü", "All", "Alle", "Todos", "Tous") }
    static var filterEarned: String { pick("Kazanılanlar", "Earned", "Erhalten", "Conseguidos", "Obtenus") }
    static var orderEasiest: String { pick("En kolay önce", "Easiest first", "Leichteste zuerst", "Más fáciles primero", "Plus faciles d'abord") }
    static var orderRarest: String { pick("En nadir önce", "Rarest first", "Seltenste zuerst", "Más raros primero", "Plus rares d'abord") }
    static var orderGame: String { pick("Oyun sırası", "Game order", "Spielreihenfolge", "Orden del juego", "Ordre du jeu") }
    static var bronze: String { pick("Bronz", "Bronze", "Bronze", "Bronce", "Bronze") }
    static var silver: String { pick("Gümüş", "Silver", "Silber", "Plata", "Argent") }
    static var gold: String { pick("Altın", "Gold", "Gold", "Oro", "Or") }
    static var platinum: String { pick("Platin", "Platinum", "Platin", "Platino", "Platine") }
    static var platinumEarned: String { pick("Platin ✓", "Platinum ✓", "Platin ✓", "Platino ✓", "Platine ✓") }
    static var guidePowerPyx: String { pick("PowerPyx rehberi", "PowerPyx guide", "PowerPyx-Guide", "Guía de PowerPyx", "Guide PowerPyx") }
    static var guidePSNProfiles: String { pick("PSNProfiles rehberleri", "PSNProfiles guides", "PSNProfiles-Guides", "Guías de PSNProfiles", "Guides PSNProfiles") }
    static var guideYouTube: String { pick("YouTube: platin yol haritası", "YouTube: platinum roadmap", "YouTube: Platin-Roadmap", "YouTube: guía del platino", "YouTube : feuille de route platine") }

    // MARK: Trophy hub
    static var overview: String { pick("Genel bakış", "Overview", "Übersicht", "Resumen", "Aperçu") }
    static var profile: String { pick("Profil", "Profile", "Profil", "Perfil", "Profil") }
    static var closestToFinish: String { pick("Bitmeye en yakın", "Closest to completion", "Kurz vor dem Abschluss", "Más cerca de completar", "Presque terminés") }
    static var recentTrophies: String { pick("Son kupalar", "Recent trophies", "Neueste Trophäen", "Trofeos recientes", "Trophées récents") }
    static var platinumCabinet: String { pick("Platin vitrini", "Platinum cabinet", "Platin-Vitrine", "Vitrina de platinos", "Vitrine des platines") }
    static var myTargets: String { pick("Hedeflerim", "My targets", "Meine Ziele", "Mis objetivos", "Mes objectifs") }
    static var library: String { pick("Oyunlar", "Games", "Spiele", "Juegos", "Jeux") }
    static func trophyLevel(_ level: Int) -> String { pick("Kupa seviyesi \(level)", "Trophy level \(level)", "Trophäenstufe \(level)", "Nivel de trofeos \(level)", "Niveau de trophées \(level)") }
    static func toNextLevel(_ fraction: Double) -> String {
        let value = percent(fraction)
        return pick("Sonraki seviyeye: \(value)", "To next level: \(value)", "Bis zur nächsten Stufe: \(value)", "Al siguiente nivel: \(value)", "Vers le niveau suivant : \(value)")
    }
    static var totalTrophies: String { pick("Toplam kupa", "Total trophies", "Trophäen gesamt", "Trofeos totales", "Trophées au total") }
    static var platinums: String { pick("Platinler", "Platinums", "Platin-Trophäen", "Platinos", "Platines") }
    static var completedGames: String { pick("%100 biten oyun", "100% games", "100-%-Spiele", "Juegos al 100 %", "Jeux à 100 %") }
    static var averageCompletion: String { pick("Ortalama tamamlama", "Average completion", "Durchschnittlicher Abschluss", "Compleción media", "Complétion moyenne") }
    static var gamesPlayed: String { pick("Oynanan oyun", "Games played", "Gespielte Spiele", "Juegos jugados", "Jeux joués") }
    static var ultraRare: String { pick("Ultra nadir", "Ultra rare", "Ultra selten", "Ultra raro", "Ultra rare") }
    static var veryRare: String { pick("Çok nadir", "Very rare", "Sehr selten", "Muy raro", "Très rare") }
    static var rare: String { pick("Nadir", "Rare", "Selten", "Raro", "Rare") }
    static var common: String { pick("Yaygın", "Common", "Häufig", "Común", "Courant") }
    static var anyRarity: String { pick("Tüm nadirlikler", "Any rarity", "Jede Seltenheit", "Cualquier rareza", "Toute rareté") }
    static var pinTarget: String { pick("Hedeflerime ekle", "Add to my targets", "Zu meinen Zielen", "Añadir a mis objetivos", "Ajouter à mes objectifs") }
    static var unpinTarget: String { pick("Hedeflerimden çıkar", "Remove from my targets", "Aus meinen Zielen entfernen", "Quitar de mis objetivos", "Retirer de mes objectifs") }
    static var notePlaceholder: String { pick("Not ekle (ör. 3. bölümde kaçırılabilir)", "Add a note (e.g. missable in chapter 3)", "Notiz (z. B. in Kapitel 3 verpassbar)", "Añade una nota (p. ej. perdible en el cap. 3)", "Ajouter une note (ex. manquable au chap. 3)") }
    static var noTargets: String { pick("Henüz hedef yok", "No targets yet", "Noch keine Ziele", "Aún no hay objetivos", "Pas encore d'objectifs") }
    static var noTargetsHint: String { pick("Bir kupanın yanındaki raptiyeye basarak hedeflerine ekle, istersen not yaz.", "Pin a trophy to add it here, and jot down a note if you like.", "Hefte eine Trophäe an, um sie hier zu sammeln – gern mit Notiz.", "Fija un trofeo para añadirlo aquí y, si quieres, escribe una nota.", "Épinglez un trophée pour l'ajouter ici, avec une note si vous voulez.") }
    static var firstTrophy: String { pick("İlk kupa", "First trophy", "Erste Trophäe", "Primer trofeo", "Premier trophée") }
    static var latestTrophy: String { pick("Son kupa", "Latest trophy", "Letzte Trophäe", "Último trofeo", "Dernier trophée") }
    static func spanDays(_ days: Int) -> String { pick("\(days) gün", "\(days) days", "\(days) Tage", "\(days) días", "\(days) jours") }
    static var rarestEarned: String { pick("En nadir kupan", "Your rarest", "Deine seltenste", "Tu más raro", "Votre plus rare") }
    static var noPlatinums: String { pick("Henüz platin yok", "No platinums yet", "Noch keine Platin-Trophäe", "Aún no hay platinos", "Pas encore de platine") }
    static var noRecent: String { pick("Son kupa bulunamadı", "No recent trophies", "Keine neuen Trophäen", "No hay trofeos recientes", "Aucun trophée récent") }
    static var openGame: String { pick("Oyunu aç", "Open game", "Spiel öffnen", "Abrir juego", "Ouvrir le jeu") }

    // MARK: PSN errors
    static var psnNotSignedIn: String { pick("PSN hesabı bağlı değil.", "No PSN account connected.", "Kein PSN-Konto verbunden.", "No hay ninguna cuenta de PSN conectada.", "Aucun compte PSN connecté.") }
    static var psnBadToken: String { pick("Oturum anahtarı geçersiz ya da süresi dolmuş. Yeni bir anahtar al.", "The session token is invalid or expired. Get a new one.", "Das Sitzungstoken ist ungültig oder abgelaufen. Hol dir ein neues.", "El token de sesión no es válido o caducó. Consigue uno nuevo.", "Le jeton de session est invalide ou expiré. Récupérez-en un nouveau.") }
    static var psnExpired: String { pick("PSN oturumu sona erdi. Kupalar penceresinden yeniden bağlan.", "Your PSN session ended. Reconnect from the Trophies window.", "Deine PSN-Sitzung ist abgelaufen. Verbinde dich im Trophäen-Fenster neu.", "Tu sesión de PSN terminó. Vuelve a conectarte desde Trofeos.", "Votre session PSN a expiré. Reconnectez-vous depuis Trophées.") }
    static func psnServer(_ code: Int) -> String { pick("PSN yanıt vermedi (hata \(code)). Biraz sonra tekrar dene.", "PSN didn't respond (error \(code)). Try again shortly.", "PSN antwortet nicht (Fehler \(code)). Versuche es gleich noch einmal.", "PSN no respondió (error \(code)). Inténtalo de nuevo en un rato.", "Le PSN ne répond pas (erreur \(code)). Réessayez dans un instant.") }
}
