import Foundation

/// Which service turns a subtitle into the target language.
enum TranslationEngine: String, CaseIterable, Identifiable {
    /// Apple's on-device translation: free, offline, private.
    case apple
    /// DeepL API with the user's own key (the free plan covers 500,000 characters a month).
    case deepl
    /// Claude Haiku with the user's own Anthropic key; reads the previous lines for context.
    case claude
    /// A model running on this Mac through Ollama (or LM Studio): free, private, no key.
    case local

    var id: String { rawValue }

    /// Where the user's key for this engine is kept (SecureStore).
    var keyName: String? {
        switch self {
        case .apple: return nil
        case .deepl: return "deepl.apiKey"
        case .claude: return "anthropic.apiKey"
        case .local: return nil
        }
    }

    var apiKey: String? {
        guard let keyName, let key = SecureStore.string(for: keyName)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else { return nil }
        return key
    }

    /// Set up enough to try: a key for the cloud engines, nothing for the local one.
    var isReady: Bool {
        switch self {
        case .apple: return false
        case .local: return true
        default: return apiKey != nil
        }
    }

    /// The local server's OpenAI-compatible address and model name (Ollama defaults).
    static var localURL: String {
        get { UserDefaults.standard.string(forKey: "local.url") ?? "http://127.0.0.1:11434/v1" }
        set { UserDefaults.standard.set(newValue, forKey: "local.url") }
    }
    static var localModel: String {
        get { UserDefaults.standard.string(forKey: "local.model") ?? "qwen2.5:3b" }
        set { UserDefaults.standard.set(newValue, forKey: "local.model") }
    }
}

enum CloudTranslatorError: LocalizedError {
    case http(Int, String)
    case emptyReply
    case refused

    var errorDescription: String? {
        switch self {
        case .http(let code, let message): return "HTTP \(code): \(message)"
        case .emptyReply: return "Empty reply"
        case .refused: return "Refused"
        }
    }
}

/// A line shown earlier, with the translation the player saw.
struct ContextLine: Sendable {
    let source: String
    let translation: String?
}

/// Online translation through DeepL or Claude. The caller falls back to Apple's translation on any error,
/// so a missing network or a used-up quota never leaves the screen empty.
@MainActor
final class CloudTranslator {
    static let shared = CloudTranslator()

    private var cache: [String: String] = [:]
    private var inFlight: [String: Task<String, Error>] = [:]
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// `context` holds the lines shown just before this one (oldest first); both engines use it to keep
    /// names, gender and tone consistent across a conversation.
    func translate(_ text: String, from source: String, to target: String, context: [ContextLine],
                   names: [String] = [], terms: [(en: String, tr: String)] = [],
                   engine: TranslationEngine) async throws -> String {
        let key = "\(engine.rawValue)|\(source)>\(target)|\(text)"
        if let hit = cache[key] { return hit }
        if let running = inFlight[key] { return try await running.value }
        let apiKey = engine.apiKey ?? ""
        if engine != .local, apiKey.isEmpty { throw CloudTranslatorError.http(401, "No API key") }

        let task = Task<String, Error> {
            switch engine {
            case .deepl: return try await self.deepl(text, from: source, to: target,
                                                     context: context.map(\.source), key: apiKey)
            case .claude: return try await self.claude(text, from: source, to: target, context: context,
                                                       names: names, terms: terms, key: apiKey)
            case .local: return try await self.local(text, from: source, to: target, context: context,
                                                     names: names, terms: terms)
            case .apple: throw CloudTranslatorError.emptyReply
            }
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        let result = try await task.value
        if cache.count > 3000 { cache.removeAll() }
        cache[key] = result
        return result
    }

    /// Sends one tiny request to check that the key works; returns nil when it does, else the error text.
    func check(_ engine: TranslationEngine) async -> String? {
        do {
            _ = try await translate("Hello there.", from: "en", to: "tr", context: [], engine: engine)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: DeepL

    private func deepl(_ text: String, from source: String, to target: String, context: [String],
                       key: String) async throws -> String {
        // Free-plan keys end in ":fx" and live on their own host.
        let host = key.hasSuffix(":fx") ? "api-free.deepl.com" : "api.deepl.com"
        var request = URLRequest(url: URL(string: "https://\(host)/v2/translate")!)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "text": [text],
            "source_lang": Self.deeplSource(source),
            "target_lang": Self.deeplTarget(target),
            "preserve_formatting": true,
        ]
        // Context is read but not translated or billed.
        if !context.isEmpty { body["context"] = context.joined(separator: "\n") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let json = try await send(request)
        guard let translations = json["translations"] as? [[String: Any]],
              let result = translations.first?["text"] as? String, !result.isEmpty else {
            throw CloudTranslatorError.emptyReply
        }
        return result
    }

    private static func deeplSource(_ code: String) -> String {
        String(code.split(separator: "-").first ?? Substring(code)).uppercased()
    }

    private static func deeplTarget(_ code: String) -> String {
        switch code {
        case "en": return "EN-US"
        case "pt": return "PT-BR"
        case "zh-Hans": return "ZH-HANS"
        case "zh-Hant": return "ZH-HANT"
        default: return deeplSource(code)
        }
    }

    // MARK: Claude

    private static let claudeModel = "claude-haiku-5-5"

    /// The instructions and the message both AI engines get: style rules, names, glossary, earlier lines.
    private static func prompt(_ text: String, from source: String, to target: String, context: [ContextLine],
                               names: [String], terms: [(en: String, tr: String)]) -> (system: String, user: String) {
        let english = Locale(identifier: "en")
        let from = english.localizedString(forIdentifier: source) ?? source
        let to = english.localizedString(forIdentifier: target) ?? target
        let system = """
        You translate \(from) video game subtitles into natural, spoken \(to), the way people really talk. \
        Characters address each other informally (in Turkish use "sen", not "siz") unless the line is clearly formal. \
        Keep swearing and slang at the same strength; do not soften or censor. \
        Keep character names, place names, brand names and speaker labels such as "LUCIA:" exactly as they are. \
        Keep the meaning and tone; do not add or leave out anything. Keep it short enough to read in a few seconds. \
        The text is read from the screen by OCR and may have misread or missing letters ("Y u ave to ask?", \
        "Doesn't 00k good."); translate the line the speaker clearly meant. \
        A subtitle may continue the previous one (it starts in lowercase or with a word like "and"); \
        translate it so that it reads as that continuation. \
        Reply with only the translation, no explanations, notes or quotes.
        """
        var parts: [String] = []
        if !names.isEmpty {
            parts.append("Names (keep exactly as written): " + names.joined(separator: ", "))
        }
        if !terms.isEmpty {
            parts.append("Preferred wording for this game:\n" + terms.map { "\($0.en) → \($0.tr)" }.joined(separator: "\n"))
        }
        if !context.isEmpty {
            var lines = ["Previous subtitles, for context only (do not translate them again):"]
            for line in context {
                lines.append("\(from): \(line.source)")
                if let translation = line.translation { lines.append("\(to): \(translation)") }
            }
            parts.append(lines.joined(separator: "\n"))
        }
        parts.append("Translate this subtitle:\n" + text)
        return (system, parts.joined(separator: "\n\n"))
    }


    private func claude(_ text: String, from source: String, to target: String, context: [ContextLine],
                        names: [String], terms: [(en: String, tr: String)], key: String) async throws -> String {
        let (system, prompt) = Self.prompt(text, from: source, to: target, context: context, names: names, terms: terms)
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": Self.claudeModel,
            "max_tokens": 400,
            // A subtitle needs no reasoning; skipping it keeps the reply fast.
            "thinking": ["type": "disabled"],
            "output_config": ["effort": "low"],
            "system": system,
            "messages": [["role": "user", "content": prompt]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let json = try await send(request)
        if json["stop_reason"] as? String == "refusal" { throw CloudTranslatorError.refused }
        let content = json["content"] as? [[String: Any]] ?? []
        let result = content.filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw CloudTranslatorError.emptyReply }
        return result
    }

    // MARK: Local model

    private func local(_ text: String, from source: String, to target: String, context: [ContextLine],
                       names: [String], terms: [(en: String, tr: String)]) async throws -> String {
        let (system, prompt) = Self.prompt(text, from: source, to: target, context: context, names: names, terms: terms)
        let base = TranslationEngine.localURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: base + "/chat/completions") else { throw CloudTranslatorError.http(0, "Bad address") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // The first line after a long pause may wait for the model to load.
        request.timeoutInterval = 20
        let body: [String: Any] = [
            "model": TranslationEngine.localModel,
            "temperature": 0,
            "max_tokens": 300,
            // Ollama: keep the model in memory between lines; no reasoning for a subtitle.
            "keep_alive": "24h",
            "think": false,
            "messages": [["role": "system", "content": system], ["role": "user", "content": prompt]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let json = try await send(request)
        let message = ((json["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String
        var result = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        // Small models sometimes wrap the answer in quotes or leave a thinking block.
        if let end = result.range(of: "</think>") { result = String(result[end.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines) }
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))
        guard !result.isEmpty else { throw CloudTranslatorError.emptyReply }
        return result
    }

    // MARK: HTTP

    private func send(_ request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(status) else {
            let message = (json["message"] as? String)
                ?? ((json["error"] as? [String: Any])?["message"] as? String)
                ?? String(data: data.prefix(200), encoding: .utf8) ?? ""
            throw CloudTranslatorError.http(status, message)
        }
        return json
    }
}
