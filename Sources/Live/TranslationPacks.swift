import AppKit
import Foundation

/// Hand-made translations for a game's lines and phrases, loaded from JSON files in
/// ~/Library/Application Support/Tercana/Packs. A line that matches a pack entry uses the pack's
/// translation instead of machine translation.
///
/// File format:
/// { "name": "My game", "language": "en-to-tr", "terms": [ { "en": "No cap.", "tr": "Yalan yok." } ] }
final class TranslationPacks {
    static let shared = TranslationPacks()

    struct Pack: Decodable {
        struct Term: Decodable { let en: String; let tr: String }
        let name: String
        let language: String?
        let terms: [Term]
    }

    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Tercana/Packs", isDirectory: true)
    }

    private(set) var names: [String] = []
    /// "source>target" → normalized source line → translation.
    private var lookup: [String: [String: String]] = [:]

    private init() { reload() }

    func reload() {
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: Self.folder, includingPropertiesForKeys: nil)) ?? []
        var lookup: [String: [String: String]] = [:]
        var names: [String] = []
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
        }
        self.lookup = lookup
        self.names = names
    }

    /// The pack translation for the whole line, if a pack has it.
    func translation(of line: String, from source: String, to target: String) -> String? {
        lookup["\(source)>\(target)"]?[Self.normalize(line)]
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
