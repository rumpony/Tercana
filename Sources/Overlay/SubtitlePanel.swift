import AppKit
import SwiftUI

/// Shows the live translation, either over the original subtitle text or just below the region.
@MainActor
final class SubtitlePanel {
    private let panel = FloatingPanel(clickThrough: true)

    var windowNumber: Int { panel.windowNumber }

    /// `textRect` is where the original text was found; covering mode sizes the box to it rather
    /// than blacking out the whole region.
    func update(_ state: LiveTranslator.State, region: CGRect, textRect: CGRect?) {
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
        let width = min(max(target.width, 280), max(region.width, 280))
        let view = SubtitleView(text: text, dimmed: dimmed, fontSize: prefs.subtitleFontSize, width: width,
                                minHeight: cover ? target.height : 0, background: prefs.subtitleBackground)
        panel.host(view)
        let size = panel.contentView?.fittingSize ?? CGSize(width: width, height: 40)
        let origin: CGPoint
        if cover {
            origin = CGPoint(x: target.midX - size.width / 2, y: target.midY - size.height / 2)
        } else {
            origin = CGPoint(x: region.midX - size.width / 2, y: region.minY - 6 - size.height)
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
    let width: CGFloat
    let minHeight: CGFloat
    let background: Double

    /// "ENZO: Ciao." → the name in the accent colour games use for speakers, the line in white.
    private var styled: Text {
        let parts = SubtitleText.splitSpeaker(text)
        guard !dimmed, let speaker = parts.speaker else { return Text(text) }
        let name = Text(speaker + ": ").foregroundColor(Color(red: 1.0, green: 0.82, blue: 0.3))
        return Text("\(name)\(parts.line)")
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
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(width: width)
            .frame(minHeight: minHeight)
            .background(Color.black.opacity(background), in: RoundedRectangle(cornerRadius: 8))
    }
}
