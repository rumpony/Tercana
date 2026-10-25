import CoreGraphics
import Foundation

/// Turns raw recognized lines into the subtitle we actually want to translate.
enum SubtitleText {
    struct Result {
        let text: String
        /// Union of the kept lines, normalized to the captured image (origin bottom-left).
        let box: CGRect?
        let dropped: [String]
    }

    /// Words that only ever appear as on-screen button prompts.
    private static let promptWords: Set<String> = [
        "SKIP", "RESUME", "BACK", "MENU", "MAIN", "OPTIONS", "SELECT", "CONFIRM", "CANCEL",
        "CONTINUE", "PAUSE", "HOLD", "PRESS", "TO", "OK",
    ]

    /// Real subtitle lines come back near 1.0; texture on busy backgrounds read as
    /// "x,:4¥ T." or "Kil" sits at 0.3–0.5 (measured on recorded game frames).
    static let minimumConfidence: Float = 0.6

    static func clean(_ lines: [TextReader.Line]) -> Result {
        var kept: [TextReader.Line] = []
        var dropped: [String] = []
        for line in lines {
            if line.confidence < minimumConfidence || isNoise(line.text) {
                dropped.append(line.text)
            } else {
                kept.append(line)
            }
        }
        // Two-line subtitles read as one sentence.
        let text = kept.map(\.text).joined(separator: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        let box = kept.map(\.box).reduce(nil as CGRect?) { partial, next in partial?.union(next) ?? next }
        return Result(text: text, box: box, dropped: dropped)
    }

    /// Stray characters and button prompts ("SKIP", "BACK TO MAIN MENU") that sit inside the region.
    /// All-caps dialogue ("GET DOWN!") is kept: it has punctuation or words outside the prompt list.
    private static func isNoise(_ line: String) -> Bool {
        let letters = line.filter(\.isLetter)
        guard letters.count >= 2 else { return true }
        guard !letters.contains(where: \.isLowercase) else { return false }
        let words = line.uppercased().split { !$0.isLetter }.map(String.init)
        return !words.isEmpty && words.allSatisfy(promptWords.contains)
    }
}

/// Recognition flickers between frames (a letter here, a comma there), so a reading only
/// counts once it has been seen twice in a row. Readings that differ by a character or two
/// count as the same.
struct SubtitleStabilizer {
    enum Change: Equatable {
        case show(String)
        case clear
    }

    private var candidate = ""
    private var seen = 0
    private var current: String?

    mutating func feed(_ text: String) -> Change? {
        if Self.similar(text, candidate) {
            seen += 1
            // Prefer the longer reading; flicker usually drops characters rather than adding them.
            if text.count > candidate.count { candidate = text }
        } else {
            candidate = text
            seen = 1
        }
        guard seen >= 2 else { return nil }
        if let current, Self.similar(candidate, current) { return nil }
        let wasShowing = current.map { !$0.isEmpty } ?? false
        current = candidate
        if candidate.isEmpty { return wasShowing ? .clear : nil }
        return .show(candidate)
    }

    /// Same text give or take ~8% of characters.
    static func similar(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        if a.isEmpty || b.isEmpty { return false }
        let x = Array(a.lowercased()), y = Array(b.lowercased())
        let longest = max(x.count, y.count)
        guard abs(x.count - y.count) <= max(2, longest / 12) else { return false }
        var previous = Array(0...y.count)
        for i in 1...x.count {
            var row = [i] + Array(repeating: 0, count: y.count)
            for j in 1...y.count {
                row[j] = min(previous[j] + 1, row[j - 1] + 1, previous[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
            }
            previous = row
        }
        return Double(previous[y.count]) <= max(1, Double(longest) * 0.08)
    }
}
