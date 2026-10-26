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
    static var connectStep1: String { pick("Tarayıcında Sony hesabına giriş yap.", "Sign in to your Sony account in your browser.", "Melde dich im Browser bei deinem Sony-Konto an.", "Inicia sesión en tu cuenta de Sony en el navegador.", "Connectez-vous à votre compte Sony dans le navigateur.") }
    static var signInSony: String { pick("Sony'ye giriş yap", "Sign in to Sony", "Bei Sony anmelden", "Iniciar sesión en Sony", "Se connecter à Sony") }
    static var invalidLoginHint: String { pick("Sayfa \"Invalid login\" gösteriyorsa aynı tarayıcıda önce \"Sony'ye giriş yap\" ile giriş yapıp sayfayı yenile.", "If the page says \"Invalid login\", sign in with \"Sign in to Sony\" in the same browser, then reload it.", "Zeigt die Seite „Invalid login“, melde dich im selben Browser über „Bei Sony anmelden“ an und lade sie neu.", "Si la página dice «Invalid login», inicia sesión con «Iniciar sesión en Sony» en el mismo navegador y recárgala.", "Si la page indique « Invalid login », connectez-vous via « Se connecter à Sony » dans le même navigateur, puis rechargez-la.") }
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
    static func spanDays(_ days: Int) -> String {
        days == 1
            ? pick("1 gün", "1 day", "1 Tag", "1 día", "1 jour")
            : pick("\(days) gün", "\(days) days", "\(days) Tage", "\(days) días", "\(days) jours")
    }
    static func trophyCount(_ n: Int) -> String {
        n == 1
            ? pick("1 kupa", "1 trophy", "1 Trophäe", "1 trofeo", "1 trophée")
            : pick("\(n) kupa", "\(n) trophies", "\(n) Trophäen", "\(n) trofeos", "\(n) trophées")
    }
    static var rarestEarned: String { pick("En nadir kupan", "Your rarest", "Deine seltenste", "Tu más raro", "Votre plus rare") }
    static var noPlatinums: String { pick("Henüz platin yok", "No platinums yet", "Noch keine Platin-Trophäe", "Aún no hay platinos", "Pas encore de platine") }
    static var noRecent: String { pick("Son kupa bulunamadı", "No recent trophies", "Keine neuen Trophäen", "No hay trofeos recientes", "Aucun trophée récent") }
    static var openGame: String { pick("Oyunu aç", "Open game", "Spiel öffnen", "Abrir juego", "Ouvrir le jeu") }

    // MARK: Statistics
    static var statistics: String { pick("İstatistikler", "Statistics", "Statistiken", "Estadísticas", "Statistiques") }
    static var summary: String { pick("Özet", "Summary", "Zusammenfassung", "Resumen", "Résumé") }
    static var showcase: String { pick("Vitrinim", "My showcase", "Meine Vitrine", "Mi vitrina", "Ma vitrine") }
    static var showcaseEmpty: String { pick("Kazandığın bir kupanın yanındaki yıldıza basarak buraya ekle.", "Star an earned trophy to show it here.", "Markiere eine erhaltene Trophäe mit dem Stern, um sie hier zu zeigen.", "Marca con la estrella un trofeo conseguido para mostrarlo aquí.", "Ajoutez l'étoile à un trophée obtenu pour l'afficher ici.") }
    static var addToShowcase: String { pick("Vitrine ekle", "Add to showcase", "Zur Vitrine hinzufügen", "Añadir a la vitrina", "Ajouter à la vitrine") }
    static var removeFromShowcase: String { pick("Vitrinden çıkar", "Remove from showcase", "Aus der Vitrine entfernen", "Quitar de la vitrina", "Retirer de la vitrine") }
    static var statsNeedSync: String { pick("Önce tam senkron gerekiyor", "A full sync is needed first", "Zuerst ist eine vollständige Synchronisierung nötig", "Primero hace falta una sincronización completa", "Une synchronisation complète est d'abord nécessaire") }
    static var statsNeedSyncHint: String { pick("İstatistikler bütün oyunlarındaki kupa tarihlerinden hesaplanır.", "Statistics are calculated from trophy dates across all your games.", "Statistiken werden aus den Trophäendaten aller Spiele berechnet.", "Las estadísticas se calculan con las fechas de trofeos de todos tus juegos.", "Les statistiques sont calculées à partir des dates de trophées de tous vos jeux.") }
    static var fullSyncTitle: String { pick("Tam senkron", "Full sync", "Vollständige Synchronisierung", "Sincronización completa", "Synchronisation complète") }
    static func fullSyncExplain(_ games: Int) -> String { pick("\(games) oyunun kupaları tek tek indirilir (yaklaşık \(max(1, games * 2 / 60)) dk). Sonraki senkronlar sadece değişen oyunları günceller.", "Downloads trophies for \(games) games one by one (about \(max(1, games * 2 / 60)) min). Later syncs only update games that changed.", "Lädt die Trophäen von \(games) Spielen nacheinander (etwa \(max(1, games * 2 / 60)) Min.). Spätere Synchronisierungen aktualisieren nur geänderte Spiele.", "Descarga los trofeos de \(games) juegos uno a uno (unos \(max(1, games * 2 / 60)) min). Después solo se actualizan los juegos con cambios.", "Télécharge les trophées de \(games) jeux un par un (environ \(max(1, games * 2 / 60)) min). Ensuite, seuls les jeux modifiés sont mis à jour.") }
    static var syncExplain: String { pick("Yeni kupa kazandığın oyunlar pencere her açıldığında güncellenir.", "Games with new trophies update each time this window opens.", "Spiele mit neuen Trophäen werden bei jedem Öffnen aktualisiert.", "Los juegos con trofeos nuevos se actualizan al abrir esta ventana.", "Les jeux avec de nouveaux trophées sont mis à jour à chaque ouverture.") }
    static func syncing(_ done: Int, _ total: Int) -> String { pick("Senkronlanıyor… \(done)/\(total)", "Syncing… \(done)/\(total)", "Synchronisiere… \(done)/\(total)", "Sincronizando… \(done)/\(total)", "Synchronisation… \(done)/\(total)") }
    static func lastSynced(_ when: String) -> String { pick("Son senkron: \(when)", "Last synced: \(when)", "Zuletzt synchronisiert: \(when)", "Última sincronización: \(when)", "Dernière synchro : \(when)") }
    static var startFullSync: String { pick("Tam senkronu başlat", "Start Full Sync", "Synchronisierung starten", "Iniciar sincronización", "Lancer la synchro") }
    static var syncNow: String { pick("Şimdi senkronla", "Sync Now", "Jetzt synchronisieren", "Sincronizar ahora", "Synchroniser") }
    static var stop: String { pick("Durdur", "Stop", "Stoppen", "Detener", "Arrêter") }
    static var streaks: String { pick("Seriler", "Streaks", "Serien", "Rachas", "Séries") }
    static var longestStreak: String { pick("En uzun seri", "Longest streak", "Längste Serie", "Racha más larga", "Plus longue série") }
    static var currentStreak: String { pick("Şu anki seri", "Current streak", "Aktuelle Serie", "Racha actual", "Série actuelle") }
    static var busiestDay: String { pick("En verimli gün", "Busiest day", "Bester Tag", "Día más productivo", "Meilleure journée") }
    static var milestones: String { pick("Kilometre taşları", "Milestones", "Meilensteine", "Hitos", "Jalons") }
    static var milestoneFirstTrophy: String { pick("İlk kupan", "First trophy", "Erste Trophäe", "Primer trofeo", "Premier trophée") }
    static func milestoneTrophyNumber(_ n: Int) -> String { pick("\(n). kupa", "Trophy #\(n)", "Trophäe Nr. \(n)", "Trofeo n.º \(n)", "Trophée n° \(n)") }
    static func milestonePlatinumNumber(_ n: Int) -> String { pick("\(n). platin", "Platinum #\(n)", "Platin Nr. \(n)", "Platino n.º \(n)", "Platine n° \(n)") }
    static var rarestTrophies: String { pick("En nadir kupaların", "Your rarest trophies", "Deine seltensten Trophäen", "Tus trofeos más raros", "Vos trophées les plus rares") }
    static var fastestPlatinums: String { pick("En hızlı platinler", "Fastest platinums", "Schnellste Platin-Trophäen", "Platinos más rápidos", "Platines les plus rapides") }
    static var lastTwelveMonths: String { pick("Son 12 ay", "Last 12 months", "Letzte 12 Monate", "Últimos 12 meses", "12 derniers mois") }
    static var byYear: String { pick("Yıllara göre", "By year", "Nach Jahr", "Por año", "Par année") }
    static var byWeekday: String { pick("Haftanın günlerine göre", "By day of the week", "Nach Wochentag", "Por día de la semana", "Par jour de la semaine") }
    static var byHour: String { pick("Günün saatlerine göre", "By hour of day", "Nach Tageszeit", "Por hora del día", "Par heure de la journée") }
    static var breakdown: String { pick("Tür ve nadirlik dağılımı", "Grade and rarity breakdown", "Verteilung nach Typ und Seltenheit", "Reparto por tipo y rareza", "Répartition par type et rareté") }

    // MARK: Recognition & debug
    static var backgroundOpacity: String { pick("Arka plan koyuluğu", "Background opacity", "Hintergrunddeckkraft", "Opacidad del fondo", "Opacité du fond") }
    static var recognition: String { pick("Yazı tanıma", "Text recognition", "Texterkennung", "Reconocimiento de texto", "Reconnaissance du texte") }
    static var accurateRecognition: String { pick("Canlı çeviride hassas tanıma kullan", "Use accurate recognition in live mode", "Genaue Erkennung im Live-Modus", "Reconocimiento preciso en vivo", "Reconnaissance précise en direct") }
    static var accurateRecognitionHint: String { pick("Stilize oyun yazılarını daha iyi okur ama biraz daha yavaştır ve işlemciyi daha çok kullanır.", "Reads stylized game fonts better, but is a bit slower and uses more CPU.", "Erkennt stilisierte Spielschriften besser, ist aber etwas langsamer und braucht mehr CPU.", "Lee mejor las fuentes estilizadas, pero es algo más lento y usa más CPU.", "Lit mieux les polices stylisées, mais est un peu plus lente et sollicite davantage le processeur.") }
    static var debugRecording: String { pick("Hata ayıklama kaydı", "Debug recording", "Debug-Aufzeichnung", "Registro de depuración", "Enregistrement de débogage") }
    static var debugRecordingHint: String { pick("Canlı çeviri sırasında değişen her kareyi ve okunan yazıları kaydeder. Tanımayı iyileştirmek için kullanılır; disk alanı kaplar.", "Saves every changed frame and what was read during live translation, to tune recognition. Uses disk space.", "Speichert bei der Live-Übersetzung jedes geänderte Bild und den erkannten Text, um die Erkennung zu verbessern. Belegt Speicherplatz.", "Guarda cada fotograma cambiado y el texto leído durante la traducción en vivo para ajustar el reconocimiento. Ocupa espacio.", "Enregistre chaque image modifiée et le texte lu pendant la traduction en direct pour affiner la reconnaissance. Occupe de l'espace disque.") }
    static var openDebugFolder: String { pick("Kayıt klasörünü aç", "Open Recordings Folder", "Aufzeichnungsordner öffnen", "Abrir carpeta de registros", "Ouvrir le dossier des enregistrements") }
    static var debugOn: String { pick("Hata ayıklama kaydı açık", "Debug recording on", "Debug-Aufzeichnung aktiv", "Registro de depuración activado", "Enregistrement de débogage actif") }

    static var rarity: String { pick("Nadirlik", "Rarity", "Seltenheit", "Rareza", "Rareté") }

    // MARK: Remote Play prompt
    static var remotePlayPrompt: String { pick("Remote Play açıldı. Canlı çeviri başlasın mı?", "Remote Play is open. Start live translation?", "Remote Play ist offen. Live-Übersetzung starten?", "Remote Play está abierto. ¿Iniciar la traducción en vivo?", "Remote Play est ouvert. Lancer la traduction en direct ?") }
    static var remotePlayPromptHint: String { pick("Kumandadayken: ⌃⌥L ile de başlatabilirsin", "Playing with a controller? ⌃⌥L starts it too", "Mit Controller? ⌃⌥L startet sie auch", "¿Con mando? ⌃⌥L también la inicia", "À la manette ? ⌃⌥L la lance aussi") }
    static var start: String { pick("Başlat", "Start", "Starten", "Iniciar", "Lancer") }
    static var chooseArea: String { pick("Yeni alan seç", "Choose Area", "Bereich wählen", "Elegir área", "Choisir la zone") }
    static var whenRemotePlayOpens: String { pick("Remote Play açılınca", "When Remote Play opens", "Wenn Remote Play öffnet", "Al abrir Remote Play", "À l'ouverture de Remote Play") }
    static var remotePlayAsk: String { pick("Sor", "Ask", "Fragen", "Preguntar", "Demander") }
    static var remotePlayStart: String { pick("Otomatik başlat", "Start automatically", "Automatisch starten", "Iniciar automáticamente", "Lancer automatiquement") }
    static var remotePlayNothing: String { pick("Hiçbir şey yapma", "Do nothing", "Nichts tun", "No hacer nada", "Ne rien faire") }

    // MARK: PSN web sign-in
    static var signInWithPlayStation: String { pick("PlayStation ile giriş yap", "Sign in with PlayStation", "Mit PlayStation anmelden", "Iniciar sesión con PlayStation", "Se connecter avec PlayStation") }
    static var connectIntroShort: String { pick("Sony'nin giriş sayfası bu uygulamanın içinde açılır. Giriş yapınca SubLens kupalarını okuyabilir; şifren SubLens'e hiç gelmez.", "Sony's sign-in page opens inside the app. Once you sign in, SubLens can read your trophies; your password never reaches SubLens.", "Sonys Anmeldeseite öffnet sich in der App. Danach kann SubLens deine Trophäen lesen; dein Passwort erreicht SubLens nie.", "La página de inicio de sesión de Sony se abre dentro de la app. Después, SubLens puede leer tus trofeos; tu contraseña nunca llega a SubLens.", "La page de connexion de Sony s'ouvre dans l'app. Ensuite, SubLens peut lire vos trophées ; votre mot de passe ne lui parvient jamais.") }
    static var webLoginHint: String { pick("Sony hesabınla giriş yap. Bitince bu pencere kendiliğinden kapanır.", "Sign in with your Sony account. This window closes by itself when you're done.", "Melde dich mit deinem Sony-Konto an. Das Fenster schließt sich danach selbst.", "Inicia sesión con tu cuenta de Sony. Esta ventana se cierra sola al terminar.", "Connectez-vous avec votre compte Sony. Cette fenêtre se ferme toute seule ensuite.") }
    static var advancedManualToken: String { pick("Gelişmiş: anahtarı elle gir", "Advanced: enter the token by hand", "Erweitert: Token manuell eingeben", "Avanzado: introducir el token a mano", "Avancé : saisir le jeton manuellement") }
    static var manualStep: String { pick("playstation.com'a giriş yaptığın tarayıcıda bu sayfadaki \"npsso\" değerini kopyala:", "In a browser signed in to playstation.com, copy the \"npsso\" value from this page:", "Kopiere im bei playstation.com angemeldeten Browser den „npsso“-Wert von dieser Seite:", "En un navegador con sesión en playstation.com, copia el valor «npsso» de esta página:", "Dans un navigateur connecté à playstation.com, copiez la valeur « npsso » de cette page :") }

    // MARK: Home
    static var openSubLens: String { pick("SubLens'i aç", "Open SubLens", "SubLens öffnen", "Abrir SubLens", "Ouvrir SubLens") }
    static var homeTab: String { pick("Ana sayfa", "Home", "Start", "Inicio", "Accueil") }
    static var settingsTab: String { pick("Ayarlar", "Settings", "Einstellungen", "Ajustes", "Réglages") }
    static var liveOn: String { pick("Canlı çeviri açık", "Live translation is on", "Live-Übersetzung läuft", "Traducción en vivo activada", "Traduction en direct activée") }
    static var liveOff: String { pick("Canlı çeviri kapalı", "Live translation is off", "Live-Übersetzung aus", "Traducción en vivo desactivada", "Traduction en direct désactivée") }

    static var signOutPSN: String { pick("PSN'den çıkış yap", "Sign out of PSN", "Von PSN abmelden", "Cerrar sesión en PSN", "Se déconnecter du PSN") }
    static var pressShortcut: String { pick("Kısayola bas…", "Press keys…", "Tasten drücken…", "Pulsa las teclas…", "Appuyez sur les touches…") }
    static var restoreDefault: String { pick("Varsayılana dön", "Restore default", "Standard wiederherstellen", "Restaurar", "Rétablir") }
    static var shortcutHint: String { pick("Değiştirmek için kısayola tıkla ve yeni tuşlara bas (en az bir ⌃ ⌥ ⌘ tuşuyla). Esc: vazgeç.", "Click a shortcut and press the new keys (with at least one of ⌃ ⌥ ⌘). Esc cancels.", "Klicke auf ein Kürzel und drücke die neuen Tasten (mit ⌃ ⌥ oder ⌘). Esc bricht ab.", "Haz clic en un atajo y pulsa las nuevas teclas (con ⌃ ⌥ o ⌘). Esc cancela.", "Cliquez sur un raccourci et appuyez sur les nouvelles touches (avec ⌃ ⌥ ou ⌘). Échap annule.") }

    // MARK: PSN errors
    static var psnNotSignedIn: String { pick("PSN hesabı bağlı değil.", "No PSN account connected.", "Kein PSN-Konto verbunden.", "No hay ninguna cuenta de PSN conectada.", "Aucun compte PSN connecté.") }
    static var psnBadToken: String { pick("Oturum anahtarı geçersiz ya da süresi dolmuş. Yeni bir anahtar al.", "The session token is invalid or expired. Get a new one.", "Das Sitzungstoken ist ungültig oder abgelaufen. Hol dir ein neues.", "El token de sesión no es válido o caducó. Consigue uno nuevo.", "Le jeton de session est invalide ou expiré. Récupérez-en un nouveau.") }
    static var psnExpired: String { pick("PSN oturumu sona erdi. Kupalar penceresinden yeniden bağlan.", "Your PSN session ended. Reconnect from the Trophies window.", "Deine PSN-Sitzung ist abgelaufen. Verbinde dich im Trophäen-Fenster neu.", "Tu sesión de PSN terminó. Vuelve a conectarte desde Trofeos.", "Votre session PSN a expiré. Reconnectez-vous depuis Trophées.") }
    static func psnServer(_ code: Int) -> String { pick("PSN yanıt vermedi (hata \(code)). Biraz sonra tekrar dene.", "PSN didn't respond (error \(code)). Try again shortly.", "PSN antwortet nicht (Fehler \(code)). Versuche es gleich noch einmal.", "PSN no respondió (error \(code)). Inténtalo de nuevo en un rato.", "Le PSN ne répond pas (erreur \(code)). Réessayez dans un instant.") }
}
