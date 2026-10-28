import CoreGraphics
import Foundation
import NaturalLanguage

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
        "CONTINUE", "PAUSE", "HOLD", "PRESS", "TO", "OK", "ROTATE", "RESET", "MOVE", "UP", "DOWN", "ZOOM", "MAP",
    ]

    /// Real subtitle lines come back near 1.0; texture on busy backgrounds read as
    /// "x,:4¥ T." or "Kil" sits at 0.3–0.5 (measured on recorded game frames).
    static let minimumConfidence: Float = 0.6

    static func clean(_ lines: [TextReader.Line]) -> Result {
        var kept: [TextReader.Line] = []
        var dropped: [String] = []
        // Control hints come back in pieces ("PRESS" · "R3" · "to CROUCH"); everything on the
        // same row as a hint word belongs to it.
        // A PS trophy notification over the subtitle area mixes its title into the line.
        if lines.contains(where: { isTrophyNotice($0.text) }) {
            return Result(text: "", box: nil, dropped: lines.map(\.text))
        }
        let hintRows = lines.filter { isControlHint($0.text) }.map(\.box)
        for line in lines {
            let onHintRow = hintRows.contains { Self.sameRow($0, line.box) }
            if onHintRow || line.confidence < minimumConfidence || isNoise(line.text) {
                dropped.append(line.text)
            } else {
                kept.append(line)
            }
        }
        // Two-line subtitles read as one sentence.
        let text = kept.map { stripDecoration($0.text) }.joined(separator: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        let box = kept.map(\.box).reduce(nil as CGRect?) { partial, next in partial?.union(next) ?? next }
        return Result(text: text, box: box, dropped: dropped)
    }

    /// Lines that aren't dialogue, all seen in recorded game frames:
    /// - stray characters,
    /// - button prompts, including ones cut off at the region edge ("SKIP", "RESUM"),
    /// - control hints ("PRESS O to take COVER"),
    /// - HUD readouts ("Swift 100%").
    /// All-caps dialogue ("GET DOWN!") is kept: it has words outside the prompt list.
    private static func isNoise(_ line: String) -> Bool {
        let text = stripDecoration(line)
        let letters = text.filter(\.isLetter)
        guard letters.count >= 2 else { return true }
        let words = text.uppercased().split { !$0.isLetter }.map(String.init)
        if isControlHint(text) { return true }
        // System notifications and HUD clocks ("12:25:19 PM").
        if text.range(of: #"\b\d{1,2}:\d{2}(:\d{2})?\b"#, options: .regularExpression) != nil { return true }
        if text.contains("%"), words.count <= 3 { return true }
        guard !letters.contains(where: \.isLowercase) else { return false }
        // A lone short all-caps fragment ("PHI", "RASSI") is a HUD or map label; shouted lines carry punctuation.
        if words.count == 1, letters.count <= 5, !text.contains(where: { "!?.,".contains($0) }) { return true }
        return !words.isEmpty && words.allSatisfy { word in
            word.count >= 2 && promptWords.contains { $0 == word || ($0.hasPrefix(word) && word.count >= 3) }
        }
    }

    private static func isTrophyNotice(_ line: String) -> Bool {
        line.range(of: #"^(Bronze?|Silver|Gold|Platinum|Gümüş|Altın|Platin)\b|Hidden [Tt]rophy|Gizli kupa|Trophy earned|Kupa kazan"#,
                   options: .regularExpression) != nil
    }

    private static func isControlHint(_ line: String) -> Bool {
        let first = stripDecoration(line).uppercased().split { !$0.isLetter }.first.map(String.init)
        return first.map { ["PRESS", "HOLD", "TAP", "USE"].contains($0) } ?? false
    }

    /// Boxes whose vertical spans mostly overlap.
    private static func sameRow(_ a: CGRect, _ b: CGRect) -> Bool {
        let overlap = min(a.maxY, b.maxY) - max(a.minY, b.minY)
        return overlap > 0.5 * min(a.height, b.height)
    }

    /// Bullet glyphs some games put before a speaker.
    private static func stripDecoration(_ line: String) -> String {
        line.trimmingCharacters(in: CharacterSet(charactersIn: "•·◦▪︎●-–— ").union(.whitespaces))
    }

    /// The language a line is clearly written in, when that differs from `expected`.
    /// Short exclamations are left alone: the recognizer guesses wildly on two words.
    static func likelyLanguage(of text: String, expected: String) -> String? {
        guard text.split(separator: " ").count >= 3 else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let (language, confidence) = recognizer.languageHypotheses(withMaximum: 1).first,
              confidence >= 0.85 else { return nil }
        let code = language == .simplifiedChinese ? "zh-Hans" : language.rawValue
        return code == expected ? nil : code
    }

    /// "MINE GUARD: Almost." → ("MINE GUARD", "Almost."). Names stay untranslated.
    static func splitSpeaker(_ text: String) -> (speaker: String?, line: String) {
        guard let match = text.firstMatch(of: #/^([A-Z][A-Z0-9'’ .-]{0,30}[A-Z]):\s*(.+)$/#) else { return (nil, text) }
        return (String(match.1), String(match.2))
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

    /// Same subtitle, allowing for recognition slips ("haven't eaten" / "haven treaten"):
    /// up to ~20% of characters may differ.
    static func similar(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        if a.isEmpty || b.isEmpty { return false }
        let x = Array(a.lowercased()), y = Array(b.lowercased())
        let longest = max(x.count, y.count)
        guard abs(x.count - y.count) <= max(2, longest / 5) else { return false }
        var previous = Array(0...y.count)
        for i in 1...x.count {
            var row = [i] + Array(repeating: 0, count: y.count)
            for j in 1...y.count {
                row[j] = min(previous[j] + 1, row[j - 1] + 1, previous[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
            }
            previous = row
        }
        return Double(previous[y.count]) <= max(1, Double(longest) * 0.2)
    }
}
