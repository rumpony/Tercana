import AppKit
import SwiftUI

/// Result of a one-off area translation, shown next to the area it came from.
@MainActor
final class ResultCard {
    private let panel = FloatingPanel(clickThrough: false)
    private var outsideClick: Any?
    private var escKey: Any?

    func show(original: String, translation: String?, error: String?, near area: CGRect) {
        let view = ResultView(original: original, translation: translation, error: error) { [weak self] in
            self?.close()
        }
        panel.host(view)
        let size = panel.contentView?.fittingSize ?? CGSize(width: 380, height: 160)
        let screen = NSScreen.screens.first { $0.frame.intersects(area) } ?? NSScreen.main!
        var origin = CGPoint(x: area.midX - size.width / 2, y: area.minY - 10 - size.height)
        if origin.y < screen.visibleFrame.minY { origin.y = area.maxY + 10 }
        origin.x = min(max(origin.x, screen.visibleFrame.minX + 12), screen.visibleFrame.maxX - size.width - 12)
        origin.y = min(max(origin.y, screen.visibleFrame.minY + 12), screen.visibleFrame.maxY - size.height - 12)
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
        panel.fade(visible: true, duration: 0.12)

        removeMonitors()
        outsideClick = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
        escKey = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            MainActor.assumeIsolated { self?.close() }
        }
    }

    func close() {
        removeMonitors()
        panel.orderOut(nil)
    }

    private func removeMonitors() {
        [outsideClick, escKey].compactMap { $0 }.forEach(NSEvent.removeMonitor)
        outsideClick = nil
        escKey = nil
    }
}

private struct ResultView: View {
    let original: String
    let translation: String?
    let error: String?
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let translation {
                ScrollView {
                    Text(translation)
                        .font(.system(size: 16))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 280)
            } else {
                Text(error ?? S.noTextFound)
                    .foregroundStyle(.secondary)
            }
            if !original.isEmpty {
                Divider()
                ScrollView {
                    Text(original)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
            }
            HStack {
                Spacer()
                if let translation {
                    Button(S.copy) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(translation, forType: .string)
                    }
                }
                Button(S.close, action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
