import CoreGraphics
import Vision

/// On-device text recognition.
enum TextReader {
    enum Quality: String, Codable {
        /// For the live loop: cheap enough to run several times a second.
        case fast
        /// For one-off reads where accuracy matters more than speed.
        case accurate
    }

    struct Line: Codable {
        let text: String
        /// Normalized to the image, origin bottom-left (Vision's convention).
        let box: CGRect
        let confidence: Float
    }

    /// Recognized lines, top to bottom.
    static func lines(in image: CGImage, language: String, quality: Quality) async throws -> [Line] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = quality == .fast ? .fast : .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = [Locale.Language(identifier: language)]
        let observations = try await request.perform(on: image)
        return observations
            .compactMap { observation -> Line? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return Line(text: candidate.string, box: observation.boundingBox.cgRect, confidence: candidate.confidence)
            }
            .sorted { $0.box.midY > $1.box.midY }
    }

    /// Recognized text, lines joined with newlines. Empty when nothing was found.
    static func read(_ image: CGImage, language: String, quality: Quality) async throws -> String {
        try await lines(in: image, language: language, quality: quality).map(\.text).joined(separator: "\n")
    }

    /// The fast recognizer only handles a set of Latin-script languages reliably.
    static func supportsFastMode(_ language: String) -> Bool {
        ["en", "fr", "de", "es", "it", "pt"].contains(language)
    }
}
