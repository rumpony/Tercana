import AppKit
import SwiftUI

/// Shows the live translation, either covering the original subtitle or just below it.
@MainActor
final class SubtitlePanel {
    private let panel = FloatingPanel(clickThrough: true)

    func update(_ state: LiveTranslator.State, region: CGRect) {
        let prefs = Preferences.shared
        let text: String
        let dimmed: Bool
        switch state {
        case .idle:
            panel.fade(visible: false)
            return
        case .waiting:
            // Covering mode would hide the game's own text with an empty box; stay out of the way.
            if prefs.coverOriginal {
                panel.fade(visible: false)
                return
            }
            text = S.waitingForSubtitle
            dimmed = true
        case .subtitle(let line):
            text = line
            dimmed = false
        case .problem(let message):
            text = message
            dimmed = true
        }

        let width = max(region.width, 280)
        let view = SubtitleView(text: text, dimmed: dimmed, fontSize: prefs.subtitleFontSize,
                                width: width, minHeight: prefs.coverOriginal ? region.height : 0,
                                opaque: prefs.coverOriginal)
        panel.host(view)
        let size = panel.contentView?.fittingSize ?? CGSize(width: width, height: 40)
        let origin: CGPoint
        if prefs.coverOriginal {
            origin = CGPoint(x: region.midX - size.width / 2, y: region.midY - size.height / 2)
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

private struct SubtitleView: View {
    let text: String
    let dimmed: Bool
    let fontSize: Double
    let width: CGFloat
    let minHeight: CGFloat
    let opaque: Bool

    var body: some View {
        Text(text)
            .font(.system(size: dimmed ? 13 : fontSize, weight: .medium))
            .foregroundStyle(dimmed ? .white.opacity(0.7) : .white)
            .multilineTextAlignment(.center)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(width: width)
            .frame(minHeight: minHeight)
            .background(Color.black.opacity(opaque ? 0.94 : 0.72), in: RoundedRectangle(cornerRadius: 8))
    }
}
