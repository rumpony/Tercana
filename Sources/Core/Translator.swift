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
    private var saveScheduled = false
    /// Translations kept between launches, so a line seen before (menus, recurring lines) shows at once.
    private static let cacheFile = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Tercana/translations.json")
    private static let cacheLimit = 5000

    init() {
        if let data = try? Data(contentsOf: Self.cacheFile),
           let saved = try? JSONDecoder().decode([[String]].self, from: data) {
            for pair in saved.suffix(Self.cacheLimit) where pair.count == 2 {
                if cache[pair[0]] == nil { cacheOrder.append(pair[0]) }
                cache[pair[0]] = pair[1]
            }
        }
    }
    private var inFlight: [String: Task<String, Error>] = [:]

    func translate(_ text: String, from source: String, to target: String) async throws -> String {
        let key = "\(source)>\(target)|\(text)"
        if let hit = cache[key] { return hit }
        // A prefetch for the same line may already be running; wait for it instead of asking twice.
        if let running = inFlight[key] { return try await running.value }

        let task = Task<String, Error> {
            let session = try await self.session(from: source, to: target)
            return try await session.translate(text).targetText
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        let result = try await task.value
        remember(result, for: key)
        return result
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
        if cache[key] == nil { cacheOrder.append(key) }
        cache[key] = value
        if cacheOrder.count > Self.cacheLimit {
            cache[cacheOrder.removeFirst()] = nil
        }
        scheduleSave()
    }

    /// Writes the cache a few seconds after the last new translation, off the main thread.
    private func scheduleSave() {
        guard !saveScheduled else { return }
        saveScheduled = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            self.saveScheduled = false
            let pairs = self.cacheOrder.compactMap { key in self.cache[key].map { [key, $0] } }
            Task.detached(priority: .utility) {
                guard let data = try? JSONEncoder().encode(pairs) else { return }
                try? FileManager.default.createDirectory(at: Self.cacheFile.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? data.write(to: Self.cacheFile, options: .atomic)
            }
        }
    }
}
