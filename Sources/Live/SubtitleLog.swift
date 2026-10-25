import Foundation
import Observation

/// Lines translated during this run, newest first, so missed subtitles can be read again.
@MainActor
@Observable
final class SubtitleLog {
    struct Entry: Identifiable {
        let id = UUID()
        let original: String
        let translation: String
        let time: Date
    }

    static let shared = SubtitleLog()

    private(set) var entries: [Entry] = []

    func add(original: String, translation: String) {
        if entries.first?.original == original { return }
        entries.insert(Entry(original: original, translation: translation, time: Date()), at: 0)
        if entries.count > 300 { entries.removeLast() }
    }

    func clear() {
        entries.removeAll()
    }
}
