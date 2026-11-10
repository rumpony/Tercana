import AppKit
import Foundation

/// Hand-made translations for a game's lines and phrases, loaded from JSON files in
/// ~/Library/Application Support/Tercana/Packs. A line that matches a pack entry uses the pack's
/// translation instead of machine translation.
///
/// File format:
/// { "name": "My game", "language": "en-to-tr", "names": ["Kratos", "Atreus"],
///   "terms": [ { "en": "No cap.", "tr": "Yalan yok." } ] }
/// `names` (optional) are taught to text recognition so character and place names are read correctly.
/// Lines also match with small OCR mistakes ("I'II" for "I'll").
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
    /// "source>target" → normalized source line → translation.
    private var lookup: [String: [String: String]] = [:]
    /// Character and place names from all packs, for text recognition.
    private(set) var customWords: [String] = []

    private init() { reload() }

    func reload() {
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: Self.folder, includingPropertiesForKeys: nil)) ?? []
        var lookup: [String: [String: String]] = [:]
        var names: [String] = []
        var words: Set<String> = []
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where file.pathExtension.lowercased() == "json" {
            guard let data = try? Data(contentsOf: file), let pack = try? JSONDecoder().decode(Pack.self, from: data) else {
                AppLog.write("pack skipped: \(file.lastPathComponent)")
                continue
            }
            let pair = (pack.language ?? "en-to-tr").replacingOccurrences(of: "-to-", with: ">")
            for term in pack.terms where !term.tr.isEmpty {
                lookup[pair, default: [:]][Self.normalize(term.en)] = term.tr
            }
            names.append(pack.name)
            words.formUnion(pack.names ?? [])
        }
        self.lookup = lookup
        self.names = names
        customWords = words.sorted()
    }

    /// The pack translation for the whole line, if a pack has it.
    func translation(of line: String, from source: String, to target: String) -> String? {
        guard let table = lookup["\(source)>\(target)"] else { return nil }
        let key = Self.normalize(line)
        if let exact = table[key] { return exact }
        // OCR often gets a letter or two wrong; accept a close line of about the same length.
        guard key.count >= 8 else { return nil }
        var best: (score: Double, text: String)?
        for (candidate, text) in table where abs(candidate.count - key.count) <= max(2, key.count / 10) {
            let score = Self.similarity(candidate, key)
            if score >= 0.9, score > (best?.score ?? 0) { best = (score, text) }
        }
        return best?.text
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
}
