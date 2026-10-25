import AppKit

/// Watches a screen region and keeps a translated subtitle on screen.
///
/// Each tick: capture → skip if the image hasn't changed → read text → clean → stabilize → translate.
/// Translation runs one request at a time; if subtitles move on while it's busy, only the newest
/// line is translated next.
@MainActor
final class LiveTranslator {
    enum State: Equatable {
        case idle
        case waiting
        case subtitle(String)
        case problem(String)
    }

    var onStateChange: ((State) -> Void)?
    var onStop: ((String?) -> Void)?

    private(set) var state: State = .idle {
        didSet { if state != oldValue { onStateChange?(state) } }
    }
    private(set) var isRunning = false

    var region: CGRect
    private let prefs = Preferences.shared
    private var loop: Task<Void, Never>?
    private var lastSignature: FrameSignature?
    private var lastReading = ""
    private var stabilizer = SubtitleStabilizer()
    private var pending: String?
    /// The subtitle currently on the game screen; a late translation for an older line is dropped.
    private var onScreen = ""
    private var translating = false

    init(region: CGRect) {
        self.region = region
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        state = .waiting
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isRunning else { return }
                await self.tick()
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    func stop(reason: String? = nil) {
        guard isRunning else { return }
        isRunning = false
        loop?.cancel()
        loop = nil
        pending = nil
        state = .idle
        onStop?(reason)
    }

    private func tick() async {
        let image: CGImage
        do {
            image = try await ScreenGrabber.shared.capture(region)
        } catch {
            stop(reason: error.localizedDescription)
            return
        }
        guard isRunning else { return }

        let reading: String
        let signature = FrameSignature(image)
        if let signature, let lastSignature, signature.matches(lastSignature) {
            reading = lastReading
        } else {
            let language = prefs.sourceLanguage
            let quality: TextReader.Quality = TextReader.supportsFastMode(language) ? .fast : .accurate
            guard let text = try? await TextReader.read(image, language: language, quality: quality) else { return }
            reading = SubtitleText.clean(text)
            lastSignature = signature
            lastReading = reading
        }
        guard isRunning else { return }

        switch stabilizer.feed(reading) {
        case .show(let line):
            onScreen = line
            pending = line
            translateNext()
        case .clear:
            onScreen = ""
            pending = nil
            state = .waiting
        case nil:
            break
        }
    }

    private func translateNext() {
        guard !translating, let line = pending else { return }
        pending = nil
        translating = true
        Task { [weak self] in
            guard let self else { return }
            let source = self.prefs.sourceLanguage
            let target = self.prefs.targetLanguage
            do {
                let translated = try await Translator.shared.translate(line, from: source, to: target)
                SubtitleLog.shared.add(original: line, translation: translated)
                if self.isRunning, line == self.onScreen {
                    self.state = .subtitle(translated)
                }
            } catch {
                if self.isRunning { self.state = .problem(error.localizedDescription) }
            }
            self.translating = false
            self.translateNext()
        }
    }
}
