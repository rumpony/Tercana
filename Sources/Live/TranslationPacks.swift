import AppKit
import CryptoKit
import Foundation

/// Hand-made translations for a game's lines and phrases, loaded from JSON files in
/// ~/Library/Application Support/Tercana/Packs. A line that matches a pack entry uses the pack's
/// translation instead of machine translation.
///
/// File format:
/// { "name": "My game", "language": "en-to-tr", "names": ["Kratos", "Atreus"],
///   "terms": [ { "en": "No cap.", "tr": "Yalan yok." } ] }
/// `names` (optional) are taught to text recognition so character and place names are read correctly.
/// Lines also match with small OCR mistakes ("I'II" for "I'll") or sentence by
/// sentence. Keep terms in dialogue order: the line after the last match wins close calls.
final class TranslationPacks {
    static let shared = TranslationPacks()

    struct Pack: Decodable {
        struct Term: Decodable { let en: String; let tr: String }
        let name: String
        let language: String?
        let terms: [Term]
        let names: [String]?
    }

    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Tercana/Packs", isDirectory: true)
    }

    private(set) var names: [String] = []
    /// One pack's lines for a language pair, in file order (dialogue order for packs made from game files).
    private struct Table {
        var keys: [String] = []
        var texts: [String] = []
        var exact: [String: Int] = [:]
        /// Word (3+ letters) → entries that contain it, for finding close lines without scanning all of them.
        var words: [String: [Int]] = [:]
    }
    /// "source>target" → lines.
    private var tables: [String: Table] = [:]
    /// The entry of the last matched line, per pair: the next line of dialogue usually follows it.
    private var lastMatch: [String: Int] = [:]
    /// Character and place names from all packs, for text recognition.
    private(set) var customWords: [String] = []

    /// Packs keyed by a hash of the English line (CouchSubs format 1/2: {"entries": {hex: tr}, "segments": …}).
    private var hashed: [UInt64: String] = [:]
    /// Glossary files ({"keep": [...], "<section>": [{"en", "tr"}]}): names to keep and preferred wording.
    private(set) var keepNames: [String] = []
    private var glossary: [(en: String, tr: String)] = []

    private init() { reload() }

    func reload() {
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: Self.folder, includingPropertiesForKeys: nil)) ?? []
        var tables: [String: Table] = [:]
        var names: [String] = []
        var words: Set<String> = []
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where file.pathExtension.lowercased() == "json" {
            if Self.isForeignFormat(file) { continue }
            guard let data = try? Data(contentsOf: file), let pack = try? JSONDecoder().decode(Pack.self, from: data) else {
                AppLog.write("pack skipped: \(file.lastPathComponent)")
                continue
            }
            let pair = (pack.language ?? "en-to-tr").replacingOccurrences(of: "-to-", with: ">")
            var table = tables[pair] ?? Table()
            for term in pack.terms where !term.tr.isEmpty {
                let key = Self.normalize(term.en)
                guard !key.isEmpty else { continue }
                if let index = table.exact[key] { table.texts[index] = term.tr; continue }
                let index = table.keys.count
                table.keys.append(key)
                table.texts.append(term.tr)
                table.exact[key] = index
                for word in Set(key.components(separatedBy: " ")) where word.count >= 3 { table.words[word, default: []].append(index) }
            }
            tables[pair] = table
            names.append(pack.name)
            words.formUnion(pack.names ?? [])
        }
        loadHashedAndGlossaries(files, names: &names, words: &words)
        self.tables = tables
        lastMatch = [:]
        self.names = names
        customWords = words.sorted()
    }

    /// The pack translation for the line, if a pack has it: the whole line or every sentence of it.
    func translation(of line: String, from source: String, to target: String) -> String? {
        let pair = "\(source)>\(target)"
        if pair == "en>tr", let hit = hashedTranslation(of: line) { return hit }
        guard let table = tables[pair] else { return nil }
        if let hit = match(Self.normalize(line), in: table, pair: pair) { return hit }
        // Two short lines shown together: use the pack only when it has every sentence.
        let sentences = Self.sentences(line)
        guard sentences.count > 1 else { return nil }
        var parts: [String] = []
        for sentence in sentences {
            guard let hit = match(Self.normalize(sentence), in: table, pair: pair) else { return nil }
            parts.append(hit)
        }
        return parts.joined(separator: " ")
    }

    private func match(_ key: String, in table: Table, pair: String) -> String? {
        guard !key.isEmpty else { return nil }
        if let index = table.exact[key] { lastMatch[pair] = index; return table.texts[index] }
        // OCR often gets a letter or two wrong; accept a close line of about the same length.
        // Short lines must match exactly: "Go." and "No." are one letter apart.
        guard key.count >= 8 else { return nil }
        let tokens = Set(key.components(separatedBy: " ")).filter { $0.count >= 3 }
        var shared: [Int: Int] = [:]
        for word in tokens { for index in table.words[word] ?? [] { shared[index, default: 0] += 1 } }
        let expected = lastMatch[pair].map { $0 + 1 }
        var candidates = shared.sorted { $0.value > $1.value }.prefix(60).map(\.key)
        if let expected, expected < table.keys.count, !candidates.contains(expected) { candidates.append(expected) }
        var best: (score: Double, index: Int)?
        for index in candidates {
            let candidate = table.keys[index]
            guard abs(candidate.count - key.count) <= max(2, key.count / 10) else { continue }
            var score = Self.similarity(candidate, key)
            // The line right after the last match is the likeliest one: it wins ties and close calls.
            if index == expected { score += 0.03 }
            if score >= 0.9, score > (best?.score ?? 0) { best = (score, index) }
        }
        guard let best else { return nil }
        lastMatch[pair] = best.index
        return table.texts[best.index]
    }

    /// The sentences of a line, split after . ! ? (keeping "..." together).
    static func sentences(_ line: String) -> [String] {
        var result: [String] = [], current = ""
        let chars = Array(line)
        for (i, c) in chars.enumerated() {
            current.append(c)
            let next = i + 1 < chars.count ? chars[i + 1] : " "
            if ".!?".contains(c), next == " " {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { result.append(trimmed) }
                current = ""
            }
        }
        let rest = current.trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty { result.append(rest) }
        return result
    }

    /// 1 − edit distance / longer length.
    static func similarity(_ a: String, _ b: String) -> Double {
        let x = Array(a), y = Array(b)
        guard !x.isEmpty, !y.isEmpty else { return a == b ? 1 : 0 }
        var previous = Array(0...y.count)
        for i in 1...x.count {
            var row = [i] + Array(repeating: 0, count: y.count)
            for j in 1...y.count {
                row[j] = min(previous[j] + 1, row[j - 1] + 1, previous[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
            }
            previous = row
        }
        return 1 - Double(previous[y.count]) / Double(max(x.count, y.count))
    }

    func openFolder() {
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(Self.folder)
    }

    /// Lowercase, letters and digits only, single spaces: OCR punctuation and case don't break a match.
    static func normalize(_ text: String) -> String {
        let kept = text.lowercased().unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(kept).split(separator: " ").joined(separator: " ")
    }

    // MARK: Hashed packs and glossaries

    /// Hashed packs start with "format", glossaries with "game"; checking the first bytes avoids parsing big files twice.
    private static func isForeignFormat(_ file: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return false }
        defer { try? handle.close() }
        let head = String(decoding: (try? handle.read(upToCount: 512)) ?? Data(), as: UTF8.self)
        return head.contains("\"format\"") || head.contains("\"keep\"") || head.contains("\"register\"")
    }

    private func loadHashedAndGlossaries(_ files: [URL], names: inout [String], words: inout Set<String>) {
        var hashed: [UInt64: String] = [:]
        var keep: Set<String> = []
        var glossary: [(String, String)] = []
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where file.pathExtension.lowercased() == "json" {
            guard Self.isForeignFormat(file), let data = try? Data(contentsOf: file),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let entries = object["entries"] as? [String: String] {
                for (key, text) in entries { if let n = UInt64(key, radix: 16) { hashed[n] = text } }
                for (key, text) in object["segments"] as? [String: String] ?? [:] {
                    if let n = UInt64(key, radix: 16), hashed[n] == nil { hashed[n] = text }
                }
                names.append(object["title"] as? String ?? file.deletingPathExtension().lastPathComponent)
            } else if let kept = object["keep"] as? [String] {
                keep.formUnion(kept)
                for case let section as [[String: Any]] in object.values {
                    for item in section {
                        if let en = item["en"] as? String, let tr = item["tr"] as? String, !en.isEmpty { glossary.append((en, tr)) }
                    }
                }
                names.append((object["game"] as? String).map { "\($0) (sözlük)" } ?? file.lastPathComponent)
            }
        }
        self.hashed = hashed
        keepNames = keep.sorted()
        self.glossary = glossary.map { (en: $0.0, tr: $0.1) }
        words.formUnion(keep)
    }

    private func hashedTranslation(of line: String) -> String? {
        guard !hashed.isEmpty else { return nil }
        if let hit = hashedLookup(line) { return hit }
        let sentences = Self.sentences(line)
        guard sentences.count > 1 else { return nil }
        var parts: [String] = []
        for sentence in sentences {
            guard let hit = hashedLookup(sentence) else { return nil }
            parts.append(hit)
        }
        return parts.joined(separator: " ")
    }

    /// Exact key first, then the line with typical OCR mistakes undone ("I'II", "g0t", "c1ear").
    private func hashedLookup(_ text: String) -> String? {
        if let hit = Self.hashKey(text).flatMap({ hashed[$0] }) { return hit }
        let repaired = Self.repairOCR(text)
        guard repaired != text else { return nil }
        return Self.hashKey(repaired).flatMap { hashed[$0] }
    }

    /// Fixes letters OCR confuses inside words: "II" → "ll", and 0/1/5 between letters → o/l/s.
    static func repairOCR(_ text: String) -> String {
        var result = text.replacingOccurrences(of: #"(?<=[A-Za-z'])II|II(?=[a-z])"#, with: "ll", options: .regularExpression)
        for (digit, letter) in [("0", "o"), ("1", "l"), ("5", "s")] {
            result = result.replacingOccurrences(of: "(?<=[A-Za-z])\(digit)|\(digit)(?=[a-z]{2})", with: letter,
                                                 options: .regularExpression)
        }
        // A capital I read as a lower-case l at the start of a word: "lt's" → "It's".
        return result.replacingOccurrences(of: #"\bl(?=[tf]['’]?s?\b|'m\b|'ll\b|'d\b)"#, with: "I", options: .regularExpression)
    }

    /// Glossary entries whose English appears in the line, for the online engine's prompt.
    func glossaryHints(for line: String) -> [(en: String, tr: String)] {
        let padded = " " + Self.normalize(line) + " "
        return glossary.filter { padded.contains(" " + Self.normalize($0.en) + " ") }.prefix(12).map { $0 }
    }

    /// Same key the CouchSubs packs use: tags out, NFKC, lowercase, marks dropped, letters/digits only,
    /// single spaces, then the first 8 bytes of SHA-256.
    static func hashKey(_ text: String) -> UInt64? {
        let lowered = stripTags(text).precomposedStringWithCompatibilityMapping.lowercased()
        var output = String.UnicodeScalarView()
        var gap = false
        for scalar in lowered.decomposedStringWithCanonicalMapping.unicodeScalars {
            switch scalar.properties.generalCategory {
            case .nonspacingMark, .spacingMark, .enclosingMark: continue
            case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
                 .decimalNumber, .letterNumber, .otherNumber:
                if gap, !output.isEmpty { output.append(" ") }
                gap = false
                output.append(scalar)
            default: gap = true
            }
        }
        guard !output.isEmpty else { return nil }
        let digest = SHA256.hash(data: Data(String(output).utf8))
        return digest.prefix(8).reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
    }

    private static func stripTags(_ text: String) -> String {
        guard text.contains("<") else { return text }
        return text.replacingOccurrences(of: "<[^<>]{0,40}>", with: " ", options: .regularExpression)
    }
}
