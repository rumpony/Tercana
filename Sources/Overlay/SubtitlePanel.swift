import AppKit
import SwiftUI

/// Shows the live translation, either over the original subtitle text or just below the region.
@MainActor
final class SubtitlePanel {
    private let panel = FloatingPanel(clickThrough: true)

    var windowNumber: Int { panel.windowNumber }
    private var positioningRegion: CGRect?

    /// Lets the player drag the subtitle where they want it; `endPositioning` saves the spot.
    func beginPositioning(region: CGRect) {
        positioningRegion = region
        update(.subtitle(S.positionSample), region: region, textRect: nil, force: true)
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = true
    }

    func endPositioning() {
        guard let region = positioningRegion else { return }
        positioningRegion = nil
        let prefs = Preferences.shared
        let frame = panel.frame
        let old = prefs.subtitleOffset
        let base = CGPoint(x: region.midX - frame.width / 2, y: region.minY - 6 - frame.height)
        prefs.subtitleOffset = CGPoint(x: frame.minX - base.x, y: frame.minY - base.y)
        _ = old
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = false
    }

    /// `textRect` is where the original text was found; covering mode sizes the box to it rather
    /// than blacking out the whole region.
    func update(_ state: LiveTranslator.State, region: CGRect, textRect: CGRect?) {
        update(state, region: region, textRect: textRect, force: false)
    }

    private func update(_ state: LiveTranslator.State, region: CGRect, textRect: CGRect?, force: Bool) {
        // While the player drags it, live updates would snap it back.
        if positioningRegion != nil, !force { return }
        let prefs = Preferences.shared
        let text: String
        let dimmed: Bool
        switch state {
        case .idle:
            panel.fade(visible: false)
            return
        case .waiting:
            // An empty box would only hide the game; stay out of the way.
            panel.fade(visible: false)
            return
        case .subtitle(let line):
            text = line
            dimmed = false
        case .problem(let message):
            text = message
            dimmed = true
        }

        let cover = prefs.coverOriginal && !dimmed
        let target = cover ? (textRect ?? region).insetBy(dx: -14, dy: -6) : region
        // A short line stays on one row: the box grows up to the region's width before it wraps.
        let width = max(region.width, 280)
        let minWidth = cover ? min(max(target.width, 280), width) : 280
        let view = SubtitleView(text: text, dimmed: dimmed, fontSize: prefs.subtitleFontSize,
                                minWidth: minWidth, width: width,
                                minHeight: cover ? target.height : 0, background: prefs.subtitleBackground)
        panel.host(view)
        let size = panel.contentView?.fittingSize ?? CGSize(width: width, height: 40)
        let origin: CGPoint
        if cover {
            origin = CGPoint(x: target.midX - size.width / 2, y: target.midY - size.height / 2)
        } else {
            let offset = prefs.subtitleOffset
            origin = CGPoint(x: region.midX - size.width / 2 + offset.x, y: region.minY - 6 - size.height + offset.y)
        }
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
        panel.fade(visible: true, duration: 0.12)
    }

    func close() {
        panel.orderOut(nil)
    }
}

struct SubtitleView: View {
    let text: String
    let dimmed: Bool
    let fontSize: Double
    let minWidth: CGFloat
    let width: CGFloat
    let minHeight: CGFloat
    let background: Double

    /// "ENZO: Ciao." → the name in the accent colour games use for speakers, the line in white.
    private var styled: Text {
        guard !dimmed else { return Text(text) }
        // One row per speaker; each name in amber.
        return text.split(separator: "\n").enumerated().reduce(Text("")) { result, item in
            let row = String(item.element)
            let parts = SubtitleText.splitSpeaker(row)
            let body = parts.speaker.map {
                Text($0 + ": ").foregroundColor(SpeakerColors.color(for: $0)) + Text(parts.line)
            } ?? Text(row)
            return item.offset == 0 ? body : result + Text("\n") + body
        }
    }

    var body: some View {
        styled
            .font(.system(size: dimmed ? 13 : fontSize, weight: .semibold))
            .foregroundStyle(dimmed ? .white.opacity(0.75) : .white)
            // A tight dark outline keeps the text readable over the game when the box is see-through.
            .shadow(color: .black.opacity(0.9), radius: 1, x: 0, y: 0)
            .shadow(color: .black.opacity(0.7), radius: 3, x: 0, y: 1)
            .multilineTextAlignment(.center)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minWidth: minWidth, maxWidth: width)
            .frame(minHeight: minHeight)
            // Frosted like the game's own subtitle box; the tint keeps it dark over bright scenes.
            .background {
                if background > 0 {
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
                        Color.black.opacity(background * 0.75)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
    }
}

/// One color per speaker for the whole session; a slightly misread name ("Jasen") keeps its color.
@MainActor
enum SpeakerColors {
    private static let palette: [Color] = [
        Color(red: 0.93, green: 0.74, blue: 0.36),  // amber
        Color(red: 0.55, green: 0.80, blue: 1.00),  // sky
        Color(red: 0.60, green: 0.88, blue: 0.55),  // green
        Color(red: 1.00, green: 0.62, blue: 0.70),  // pink
        Color(red: 0.80, green: 0.66, blue: 1.00),  // lilac
        Color(red: 1.00, green: 0.66, blue: 0.42),  // orange
        Color(red: 0.50, green: 0.90, blue: 0.85),  // teal
    ]
    private static var assigned: [(name: String, color: Color)] = []

    static func color(for speaker: String) -> Color {
        let key = speaker.lowercased().filter(\.isLetter)
        if let known = assigned.first(where: { close($0.name, key) }) { return known.color }
        let color = palette[assigned.count % palette.count]
        assigned.append((key, color))
        return color
    }

    private static func close(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        guard abs(a.count - b.count) <= 1, min(a.count, b.count) >= 4 else { return false }
        let x = Array(a), y = Array(b)
        var row = Array(0...y.count)
        for i in 1...x.count {
            var previous = row[0]; row[0] = i
            for j in 1...y.count {
                let current = row[j]
                row[j] = min(row[j] + 1, row[j - 1] + 1, previous + (x[i - 1] == y[j - 1] ? 0 : 1))
                previous = current
            }
        }
        return row[y.count] <= 1
    }
}
