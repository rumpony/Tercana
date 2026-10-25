import Foundation

/// Turns raw recognized text into the subtitle we actually want to translate.
enum SubtitleText {
    /// Drops on-screen button prompts ("SKIP", "BACK TO MAIN MENU") that sit inside the region:
    /// short lines with no lowercase letters. Dialogue lines such as "NAME: Get down!" keep
    /// their lowercase text and survive.
    static func clean(_ raw: String) -> String {
        let lines = raw.split(separator: "\n").filter { line in
            let letters = line.filter(\.isLetter)
            guard letters.count >= 2 else { return false }
            let shoutyLabel = !letters.contains(where: \.isLowercase) && line.count <= 30
            return !shoutyLabel
        }
        // Two-line subtitles read as one sentence.
        return lines.joined(separator: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

/// Recognition flickers between frames (a letter here, a comma there), so a reading only
/// counts once it has been seen twice in a row.
struct SubtitleStabilizer {
    enum Change: Equatable {
        case show(String)
        case clear
    }

    private var candidate = ""
    private var seen = 0
    private var current: String?

    mutating func feed(_ text: String) -> Change? {
        if text == candidate {
            seen += 1
        } else {
            candidate = text
            seen = 1
        }
        guard seen >= 2, text != current else { return nil }
        let wasShowing = current.map { !$0.isEmpty } ?? false
        current = text
        if text.isEmpty { return wasShowing ? .clear : nil }
        return .show(text)
    }
}
