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
    /// Where the subtitle text sits on screen (global coordinates), so the translation can cover
    /// just the text instead of the whole region.
    private(set) var textRect: CGRect?

    var region: CGRect
    private let prefs = Preferences.shared
    private let recorder = DebugRecorder.shared
    private var loop: Task<Void, Never>?
    private var lastSignature: FrameSignature?
    private var lastReading = SubtitleText.Result(text: "", box: nil, dropped: [])
    private var stabilizer = SubtitleStabilizer()
    private var pending: String?
    /// The subtitle currently on the game screen; a late translation for an older line is dropped.
    private var onScreen = ""
    private var translating = false
    /// When each reading was first seen, for prefetching and end-to-end timing.
    private var firstSeen: [String: ContinuousClock.Instant] = [:]

    init(region: CGRect) {
        self.region = region
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        state = .waiting
        recorder.beginSession()
        ScreenGrabber.shared.reset()
        // The first request after a while loads the translation model; do it before subtitles arrive.
        let (source, target) = (prefs.sourceLanguage, prefs.targetLanguage)
        Task { _ = try? await Translator.shared.translate("Hello.", from: source, to: target) }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isRunning else { return }
                await self.tick()
                try? await Task.sleep(for: .milliseconds(120))
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
        // With Remote Play running, anything else in front (a browser guide, a chat) covers the
        // region; recordings showed those being translated. Wait until the game is back.
        if RemotePlayWatcher.isRunning, !RemotePlayWatcher.isFrontmost { return }
        let image: CGImage
        do {
            image = try await ScreenGrabber.shared.capture(region)
        } catch {
            stop(reason: error.localizedDescription)
            return
        }
        guard isRunning else { return }

        var record: DebugRecorder.Record?
        let reading: SubtitleText.Result
        let signature = FrameSignature(image)
        if let signature, let lastSignature, signature.matches(lastSignature) {
            reading = lastReading
        } else {
            let language = prefs.sourceLanguage
            let quality: TextReader.Quality = TextReader.supportsFastMode(language) && !prefs.accurateRecognition
                ? .fast : .accurate
            let started = ContinuousClock.now
            guard let lines = try? await TextReader.lines(in: image, language: language, quality: quality) else { return }
            let ocrTime = started.duration(to: .now)
            reading = SubtitleText.clean(lines)
            lastSignature = signature
            lastReading = reading
            if recorder.isOn {
                record = await debugRecord(image: image, lines: lines, quality: quality, took: ocrTime, reading: reading)
            }
        }
        guard isRunning else { return }

        // Text already in the language we translate into (a Turkish guide, a PS notification) isn't a subtitle.
        let target = prefs.targetLanguage
        let readable = SubtitleText.likelyLanguage(of: reading.text, expected: prefs.sourceLanguage) == target
            ? "" : reading.text
        // Start translating on first sight; by the time the line is confirmed the result is
        // usually cached, which removes the confirmation wait from what the player feels.
        if !readable.isEmpty, firstSeen[readable] == nil {
            firstSeen[readable] = .now
            if firstSeen.count > 200 { firstSeen.removeAll() }
            let line = readable
            Task { _ = try? await self.translate(line) }
        }
        let change = stabilizer.feed(readable)
        switch change {
        case .show(let line):
            onScreen = line
            textRect = reading.box.map(globalRect)
            pending = line
            translateNext()
        case .clear:
            onScreen = ""
            pending = nil
            state = .waiting
        case nil:
            break
        }
        if let record {
            var final = record
            final.decision = Self.describe(change)
            recorder.log(final)
        }
    }

    private func translateNext() {
        guard !translating, let line = pending else { return }
        pending = nil
        translating = true
        Task { [weak self] in
            guard let self else { return }
            let started = ContinuousClock.now
            do {
                let translated = try await self.translate(line)
                SubtitleLog.shared.add(original: line, translation: translated)
                if self.recorder.isOn {
                    self.recorder.log(DebugRecorder.Record(
                        time: Date(), frame: nil, regionSize: self.region.size, quality: .fast, ocrMilliseconds: 0,
                        lines: [], accurateLines: nil, accurateMilliseconds: nil, cleaned: line, dropped: [],
                        decision: "translated", translation: translated,
                        translationMilliseconds: Self.milliseconds(started.duration(to: .now)),
                        endToEndMilliseconds: self.firstSeen[line].map { Self.milliseconds($0.duration(to: .now)) }))
                }
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

    /// Speaker names stay as they are; lines in another language are translated from that language.
    private func translate(_ line: String) async throws -> String {
        let source = prefs.sourceLanguage
        let target = prefs.targetLanguage
        let parts = SubtitleText.splitSpeaker(line)
        // Games mix in other languages ("Ai posti! Pronti!"); translate those from what they are.
        let from = SubtitleText.likelyLanguage(of: parts.line, expected: source) ?? source
        let body = from == target ? parts.line
            : try await Translator.shared.translate(parts.line, from: from, to: target)
        return parts.speaker.map { "\($0): \(body)" } ?? body
    }

    /// Normalized image box (origin bottom-left) → global screen rectangle.
    private func globalRect(_ box: CGRect) -> CGRect {
        CGRect(x: region.minX + box.minX * region.width, y: region.minY + box.minY * region.height,
               width: box.width * region.width, height: box.height * region.height)
    }

    private func debugRecord(image: CGImage, lines: [TextReader.Line], quality: TextReader.Quality,
                             took: Duration, reading: SubtitleText.Result) async -> DebugRecorder.Record {
        let frame = recorder.saveFrame(image)
        var accurate: [TextReader.Line]?
        var accurateTime: Duration?
        if quality == .fast {
            let started = ContinuousClock.now
            accurate = try? await TextReader.lines(in: image, language: prefs.sourceLanguage, quality: .accurate)
            accurateTime = started.duration(to: .now)
        }
        return DebugRecorder.Record(time: Date(), frame: frame, regionSize: region.size, quality: quality,
                                    ocrMilliseconds: Self.milliseconds(took), lines: lines,
                                    accurateLines: accurate, accurateMilliseconds: accurateTime.map(Self.milliseconds),
                                    cleaned: reading.text, dropped: reading.dropped, decision: "")
    }

    private static func describe(_ change: SubtitleStabilizer.Change?) -> String {
        switch change {
        case .show: return "show"
        case .clear: return "clear"
        case nil: return "hold"
        }
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)
    }
}
