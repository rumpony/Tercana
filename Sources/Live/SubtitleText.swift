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

    static func clean(_ lines: [TextReader.Line], boxOnlyIn image: CGImage? = nil) -> Result {
        var kept: [TextReader.Line] = []
        var dropped: [String] = []
        // Only filter when some line really sits on a solid box; with a see-through background nothing would pass.
        let backdrop = image.flatMap(Backdrop.init).flatMap { backdrop in
            lines.contains { $0.confidence >= minimumConfidence && !isNoise($0.text) && backdrop.isSolid(around: $0.box) }
                ? backdrop : nil
        }
        // Control hints come back in pieces ("PRESS" · "R3" · "to CROUCH"); everything on the
        // same row as a hint word belongs to it.
        // A PS trophy notification over the subtitle area mixes its title into the line.
        if lines.contains(where: { isTrophyNotice($0.text) }) {
            return Result(text: "", box: nil, dropped: lines.map(\.text))
        }
        let hintRows = lines.filter { isControlHint($0.text) }.map(\.box)
        // Lines on the box, plus lines stacked right against them: the second row of a two-line subtitle
        // sometimes samples the scene at its wider edges.
        var onBox = Set<Int>()
        if let backdrop {
            for (index, line) in lines.enumerated() where backdrop.isSolid(around: line.box) { onBox.insert(index) }
            var grew = true
            while grew {
                grew = false
                for (index, line) in lines.enumerated() where !onBox.contains(index) {
                    let touches = onBox.contains { other in
                        let o = lines[other].box
                        let gap = max(o.minY - line.box.maxY, line.box.minY - o.maxY)
                        return gap < 0.6 * min(o.height, line.box.height) && o.minX < line.box.maxX && line.box.minX < o.maxX
                    }
                    if touches { onBox.insert(index); grew = true }
                }
            }
        }
        for (index, line) in lines.enumerated() {
            let onHintRow = hintRows.contains { Self.sameRow($0, line.box) }
            let offBox = backdrop != nil && !onBox.contains(index)
            if onHintRow || offBox || line.confidence < minimumConfidence || isNoise(line.text) {
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
        // Short all-caps text without punctuation ("PHI", "TAKE AMMO PACK", "TURN ON") is a HUD label or
        // an interaction prompt; shouted dialogue carries punctuation ("GET DOWN!").
        if words.count <= 3, !text.contains(where: { "!?.,…".contains($0) }) { return true }
        return !words.isEmpty && words.allSatisfy { word in
            word.count >= 2 && promptWords.contains { $0 == word || ($0.hasPrefix(word) && word.count >= 3) }
        }
    }

    private static func isTrophyNotice(_ line: String) -> Bool {
        line.range(of: #"^(Bronze?|Silver|Gold|Platinum|Gümüş|Altın|Platin)\b|Hidden [Tt]rophy|Gizli kupa|Trophy earned|Kupa kazan"#,
                   options: .regularExpression) != nil
    }

    private static func isControlHint(_ line: String) -> Bool {
        // Button glyphs and stick/trigger names ("R3 HİKAYE KIYAFETLERİ □ KAMERA △ TAM GÖRÜNÜM").
        if line.range(of: #"[□△○◯✕✖⨯▢■▲●]|(^|\s)[LR][123](\s|$)|\b(L|R)-?STICK\b"#, options: .regularExpression) != nil {
            return true
        }
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
        line.trimmingCharacters(in: CharacterSet(charactersIn: "•·◦▪︎●-–—=_| ").union(.whitespaces))
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
    /// Splits "A: one. B: two." where a new speaker label follows the end of a sentence.
    static func splitTurns(_ text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: #"(?<=[.!?…\]]) (?=[A-Z][\w'’.-]{0,20}(?: [A-Z][\w'’.-]{0,20}){0,2}: )"#)
        var parts: [String] = []
        var start = text.startIndex
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            parts.append(String(text[start..<range.lowerBound]))
            start = range.upperBound
        }
        parts.append(String(text[start...]))
        parts = parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return parts.count > 1 && parts.allSatisfy({ splitSpeaker($0).speaker != nil }) ? parts : [text]
    }

    static func splitSpeaker(_ text: String) -> (speaker: String?, line: String) {
        // "LUCIA: …" and GTA VI's "Jason: …", "Local Cop: …" (up to three capitalized words).
        guard let match = text.firstMatch(of: #/^([A-Z][A-Z0-9'’ .-]{0,30}[A-Z]|[A-Z][\w'’.-]{0,20}(?: [A-Z#0-9][\w'’.-]{0,20}){0,2}):\s*(.+)$/#)
        else { return (nil, text) }
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

    /// Takes a line known to be complete (it matched a translation pack) without waiting for a second reading.
    mutating func confirm(_ text: String) -> Change? {
        candidate = text
        seen = 2
        if let current, Self.similar(text, current) { return nil }
        current = text
        return .show(text)
    }

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

/// Tells text on the game's solid subtitle box from text over the scene.
/// The pixels just around a line on the box are uniformly dark; a sign or HUD label sits on a busy or bright scene.
struct Backdrop {
    private let pixels: [UInt8]
    private let width: Int
    private let height: Int

    init?(_ image: CGImage) {
        let width = image.width, height = image.height
        guard width > 0, height > 0 else { return nil }
        self.width = width
        self.height = height
        var buffer = [UInt8](repeating: 0, count: width * height)
        let drawn = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        pixels = buffer
    }

    /// `box` is normalized, origin bottom-left. Samples a ring a little outside the text.
    func isSolid(around box: CGRect) -> Bool {
        let w = Double(width), h = Double(height)
        // GTA VI's box hugs the text: sample just inside its padding (tuned on recorded frames).
        let vertical = max(1, box.height * h * 0.08), horizontal = max(2, box.height * h * 0.2)
        let left = box.minX * w - horizontal, right = box.maxX * w + horizontal
        let top = (1 - box.maxY) * h - vertical, bottom = (1 - box.minY) * h + vertical
        var dark = 0, total = 0
        func sample(_ x: Double, _ y: Double) {
            let xi = Int(x), yi = Int(y)
            guard xi >= 0, yi >= 0, xi < width, yi < height else { return }
            total += 1
            if pixels[yi * width + xi] < 60 { dark += 1 }
        }
        let steps = 24
        for i in 0...steps {
            let x = left + (right - left) * Double(i) / Double(steps)
            sample(x, top); sample(x, bottom)
            let y = top + (bottom - top) * Double(i) / Double(steps)
            sample(left, y); sample(right, y)
        }
        return total >= 20 && Double(dark) >= Double(total) * 0.6
    }
}

