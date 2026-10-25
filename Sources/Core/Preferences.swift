import Foundation
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
    var batteryAlerts: Bool {
        didSet { defaults.set(batteryAlerts, forKey: Keys.batteryAlerts) }
    }
    var subtitleFontSize: Double {
        didSet { defaults.set(subtitleFontSize, forKey: Keys.subtitleFontSize) }
    }
    /// Last live region, in global AppKit coordinates.
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
        ])
        appLanguage = AppLanguage.current
        sourceLanguage = defaults.string(forKey: Keys.sourceLanguage) ?? "en"
        targetLanguage = defaults.string(forKey: Keys.targetLanguage) ?? "tr"
        coverOriginal = defaults.bool(forKey: Keys.coverOriginal)
        followRemotePlay = defaults.bool(forKey: Keys.followRemotePlay)
        batteryAlerts = defaults.bool(forKey: Keys.batteryAlerts)
        subtitleFontSize = defaults.double(forKey: Keys.subtitleFontSize)
        liveRegion = defaults.string(forKey: Keys.liveRegion).map { NSRectFromString($0) }
    }

    private enum Keys {
        static let sourceLanguage = "sourceLanguage"
        static let targetLanguage = "targetLanguage"
        static let coverOriginal = "coverOriginal"
        static let followRemotePlay = "followRemotePlay"
        static let batteryAlerts = "batteryAlerts"
        static let subtitleFontSize = "subtitleFontSize"
        static let liveRegion = "liveRegion"
    }
}

/// Languages offered in settings. Recognition quality is best for Latin scripts.
enum Language {
    static let sources = ["en", "ja", "fr", "de", "es", "it", "pt", "ru", "ko", "zh-Hans"]
    static let targets = ["tr", "en", "de", "fr", "es", "it", "pt", "ru", "ja"]
}
