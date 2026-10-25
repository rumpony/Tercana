import CoreGraphics
import Vision

/// On-device text recognition.
enum TextReader {
    enum Quality {
        /// For the live loop: cheap enough to run several times a second.
        case fast
        /// For one-off reads where accuracy matters more than speed.
        case accurate
    }

    /// Returns recognized lines top to bottom, joined with newlines. Empty when nothing was found.
    static func read(_ image: CGImage, language: String, quality: Quality) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = quality == .fast ? .fast : .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = [Locale.Language(identifier: language)]
        let observations = try await request.perform(on: image)
        return observations
            .sorted { $0.boundingBox.cgRect.midY > $1.boundingBox.cgRect.midY }  // Vision's origin is bottom-left
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    /// The fast recognizer only handles a set of Latin-script languages reliably.
    static func supportsFastMode(_ language: String) -> Bool {
        ["en", "fr", "de", "es", "it", "pt"].contains(language)
    }
}
