import Foundation
import Translation

enum TranslatorError: LocalizedError {
    case languagePackMissing(String, String)
    case unsupportedPair

    var errorDescription: String? {
        switch self {
        case .languagePackMissing: return S.errorPackMissing
        case .unsupportedPair: return S.errorUnsupportedPair
        }
    }
}

/// On-device translation through Apple's Translation framework.
/// Keeps one session per language pair; results are cached because subtitles repeat a lot.
@MainActor
final class Translator {
    static let shared = Translator()

    private var session: TranslationSession?
    private var sessionPair: (String, String)?
    private var cache: [String: String] = [:]
    private var cacheOrder: [String] = []

    func translate(_ text: String, from source: String, to target: String) async throws -> String {
        let key = "\(source)>\(target)|\(text)"
        if let hit = cache[key] { return hit }

        let session = try await session(from: source, to: target)
        let response = try await session.translate(text)
        remember(response.targetText, for: key)
        return response.targetText
    }

    static func status(from source: String, to target: String) async -> LanguageAvailability.Status {
        await LanguageAvailability().status(from: Locale.Language(identifier: source),
                                            to: Locale.Language(identifier: target))
    }

    private func session(from source: String, to target: String) async throws -> TranslationSession {
        if let session, let pair = sessionPair, pair == (source, target) { return session }
        switch await Self.status(from: source, to: target) {
        case .installed: break
        case .supported: throw TranslatorError.languagePackMissing(source, target)
        default: throw TranslatorError.unsupportedPair
        }
        let created = TranslationSession(installedSource: Locale.Language(identifier: source),
                                         target: Locale.Language(identifier: target))
        session = created
        sessionPair = (source, target)
        return created
    }

    private func remember(_ value: String, for key: String) {
        cache[key] = value
        cacheOrder.append(key)
        if cacheOrder.count > 500 {
            cache[cacheOrder.removeFirst()] = nil
        }
    }
}
