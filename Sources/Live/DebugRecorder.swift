import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Records what live translation saw and decided, so recognition can be tuned from real games.
/// Each session gets a folder with the captured frames and a `log.jsonl` line per recognition.
@MainActor
final class DebugRecorder {
    struct Record: Encodable {
        let time: Date
        let frame: String?
        let regionSize: CGSize
        let quality: TextReader.Quality
        let ocrMilliseconds: Int
        let lines: [TextReader.Line]
        /// The accurate recognizer on the same frame, for comparison.
        let accurateLines: [TextReader.Line]?
        let accurateMilliseconds: Int?
        let cleaned: String
        let dropped: [String]
        var decision: String
        var translation: String?
        var translationMilliseconds: Int?
    }

    static let shared = DebugRecorder()
    /// Half-resolution JPEGs are ~10× smaller than the PNGs were, so sessions can run for hours.
    private static let maxFrames = 30000

    static var rootFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SubLens/Debug", isDirectory: true)
    }

    private var folder: URL?
    private var frameCount = 0
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    var isOn: Bool { Preferences.shared.debugRecording }

    func beginSession() {
        guard isOn else { folder = nil; return }
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
            .replacingOccurrences(of: ":", with: "-")
        let url = Self.rootFolder.appendingPathComponent(stamp, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        folder = url
        frameCount = 0
    }

    /// Saves the frame as PNG and returns its file name.
    /// Saves the frame in the background and returns its file name right away.
    func saveFrame(_ image: CGImage) -> String? {
        guard let folder, frameCount < Self.maxFrames else { return nil }
        frameCount += 1
        let name = String(format: "%05d.jpg", frameCount)
        let url = folder.appendingPathComponent(name)
        Task.detached(priority: .utility) {
            guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
            else { return }
            let options: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: 0.7,
                kCGImageDestinationImageMaxPixelSize: max(image.width, image.height) / 2,
            ]
            CGImageDestinationAddImage(destination, image, options as CFDictionary)
            CGImageDestinationFinalize(destination)
        }
        return name
    }

    func log(_ record: Record) {
        guard let folder, var line = try? encoder.encode(record) else { return }
        line.append(0x0A)
        let url = folder.appendingPathComponent("log.jsonl")
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        } else {
            try? line.write(to: url)
        }
    }

    func openFolder() {
        try? FileManager.default.createDirectory(at: Self.rootFolder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(Self.rootFolder)
    }
}
