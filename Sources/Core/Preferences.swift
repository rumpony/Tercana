import Foundation
import Translation
import Vision
import Observation

/// User preferences backed by UserDefaults.
@MainActor
@Observable
final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    var appLanguage: AppLanguage {
        didSet { defaults.set(appLanguage.rawValue, forKey: AppLanguage.defaultsKey) }
    }
    var sourceLanguage: String {
        didSet { defaults.set(sourceLanguage, forKey: Keys.sourceLanguage) }
    }
    var targetLanguage: String {
        didSet { defaults.set(targetLanguage, forKey: Keys.targetLanguage) }
    }
    /// Draw the translation on top of the original subtitle instead of below it.
    var coverOriginal: Bool {
        didSet { defaults.set(coverOriginal, forKey: Keys.coverOriginal) }
    }
    /// Start live translation when PS Remote Play comes to the front, stop when it quits.
    var followRemotePlay: Bool {
        didSet { defaults.set(followRemotePlay, forKey: Keys.followRemotePlay) }
    }
    /// What happens when PS Remote Play opens.
    var remotePlayAction: RemotePlayAction {
        didSet { defaults.set(remotePlayAction.rawValue, forKey: Keys.remotePlayAction) }
    }
    var batteryAlerts: Bool {
        didSet { defaults.set(batteryAlerts, forKey: Keys.batteryAlerts) }
    }
    /// Opacity of the box behind the translated subtitle.
    var subtitleBackground: Double {
        didSet { defaults.set(subtitleBackground, forKey: Keys.subtitleBackground) }
    }
    /// Where the player dragged the subtitle, relative to its default spot under the region.
    var subtitleOffset: CGPoint {
        didSet { defaults.set(NSStringFromPoint(subtitleOffset), forKey: Keys.subtitleOffset) }
    }
    /// Use the slower, more thorough recognizer in live mode too.
    var accurateRecognition: Bool {
        didSet { defaults.set(accurateRecognition, forKey: Keys.accurateRecognition) }
    }
    /// Read only text sitting on a solid subtitle box (the game's subtitle background set to solid):
    /// signs, menus and HUD text around it are skipped.
    var subtitleBoxOnly: Bool {
        didSet { defaults.set(subtitleBoxOnly, forKey: Keys.subtitleBoxOnly) }
    }
    /// Save frames and recognition results for tuning.
    /// Which service translates subtitles; online engines fall back to Apple's on any error.
    var translationEngine: TranslationEngine {
        didSet { defaults.set(translationEngine.rawValue, forKey: Keys.translationEngine) }
    }
    var debugRecording: Bool {
        didSet { defaults.set(debugRecording, forKey: Keys.debugRecording) }
    }
    var subtitleFontSize: Double {
        didSet { defaults.set(subtitleFontSize, forKey: Keys.subtitleFontSize) }
    }
    /// Last live region, in global AppKit coordinates.
    /// Extra areas watched next to the subtitle (mission text, hints), each translated in place.
    var extraRegions: [CGRect] {
        didSet { defaults.set(extraRegions.map { NSStringFromRect($0) }, forKey: Keys.extraRegions) }
    }

    var liveRegion: CGRect? {
        didSet {
            if let liveRegion {
                defaults.set(NSStringFromRect(liveRegion), forKey: Keys.liveRegion)
            } else {
                defaults.removeObject(forKey: Keys.liveRegion)
            }
        }
    }

    private init() {
        defaults.register(defaults: [
            Keys.sourceLanguage: "en",
            Keys.targetLanguage: "tr",
            Keys.coverOriginal: true,
            Keys.followRemotePlay: true,
            Keys.batteryAlerts: true,
            Keys.subtitleFontSize: 20.0,
            Keys.subtitleBackground: 0.55,
            // The fast recognizer garbles low-contrast game subtitles; accurate reads them cleanly
            // in roughly 100–300 ms, well within the live loop's budget.
            Keys.accurateRecognition: true,
        ])
        subtitleBackground = defaults.double(forKey: Keys.subtitleBackground)
        accurateRecognition = defaults.bool(forKey: Keys.accurateRecognition)
        subtitleBoxOnly = defaults.bool(forKey: Keys.subtitleBoxOnly)
        subtitleOffset = defaults.string(forKey: Keys.subtitleOffset).map(NSPointFromString) ?? .zero
        debugRecording = defaults.bool(forKey: Keys.debugRecording)
        translationEngine = TranslationEngine(rawValue: defaults.string(forKey: Keys.translationEngine) ?? "") ?? .apple
        appLanguage = AppLanguage.current
        sourceLanguage = defaults.string(forKey: Keys.sourceLanguage) ?? "en"
        targetLanguage = defaults.string(forKey: Keys.targetLanguage) ?? "tr"
        coverOriginal = defaults.bool(forKey: Keys.coverOriginal)
        followRemotePlay = defaults.bool(forKey: Keys.followRemotePlay)
        remotePlayAction = RemotePlayAction(rawValue: defaults.string(forKey: Keys.remotePlayAction) ?? "") ?? .ask
        batteryAlerts = defaults.bool(forKey: Keys.batteryAlerts)
        subtitleFontSize = defaults.double(forKey: Keys.subtitleFontSize)
        liveRegion = defaults.string(forKey: Keys.liveRegion).map { NSRectFromString($0) }
        extraRegions = (defaults.stringArray(forKey: Keys.extraRegions) ?? []).map { NSRectFromString($0) }
    }

    private enum Keys {
        static let sourceLanguage = "sourceLanguage"
        static let targetLanguage = "targetLanguage"
        static let coverOriginal = "coverOriginal"
        static let followRemotePlay = "followRemotePlay"
        static let remotePlayAction = "remotePlayAction"
        static let batteryAlerts = "batteryAlerts"
        static let subtitleFontSize = "subtitleFontSize"
        static let liveRegion = "liveRegion"
        static let extraRegions = "extraRegions"
        static let subtitleBackground = "subtitleBackground"
        static let accurateRecognition = "accurateRecognition"
        static let subtitleBoxOnly = "subtitleBoxOnly"
        static let subtitleOffset = "subtitleOffset"
        static let debugRecording = "debugRecording"
        static let translationEngine = "translationEngine"
    }
}

enum RemotePlayAction: String, CaseIterable, Identifiable {
    /// Drop a small prompt from the top of the screen.
    case ask
    case start
    case nothing
    var id: String { rawValue }
}

/// Languages offered in settings. Recognition quality is best for Latin scripts.
enum Language {
    /// Shown until the system lists are in.
    static let sources = ["en", "ja", "fr", "de", "es", "it", "pt", "ru", "ko", "zh-Hans"]
    static let targets = ["tr", "en", "de", "fr", "es", "it", "pt", "ru", "ja"]

    /// Languages the on-device text recognizer can read that Apple Translation can also translate from.
    static func systemSources() async -> [String] {
        let readable = Set(RecognizeTextRequest().supportedRecognitionLanguages.map(code))
        let translatable = Set(await LanguageAvailability().supportedLanguages.map(code))
        return sortedByName(readable.intersection(translatable))
    }

    /// Every language Apple Translation can translate into.
    static func systemTargets() async -> [String] {
        sortedByName(Set(await LanguageAvailability().supportedLanguages.map(code)))
    }

    /// "en-US" → "en", but keep script variants like "zh-Hans" apart.
    private static func code(_ language: Locale.Language) -> String {
        let base = language.languageCode?.identifier ?? language.minimalIdentifier
        if let script = language.script?.identifier, base == "zh" { return "zh-\(script)" }
        return base
    }

    private static func sortedByName(_ codes: Set<String>) -> [String] {
        codes.sorted { S.languageName($0).localizedCompare(S.languageName($1)) == .orderedAscending }
    }
}
