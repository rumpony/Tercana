import AppKit
import SwiftUI

/// Borderless panel that floats over full-screen apps (including Remote Play) without taking focus.
class FloatingPanel: NSPanel {
    init(clickThrough: Bool) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        ignoresMouseEvents = clickThrough
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    override var canBecomeKey: Bool { false }

    func host<V: View>(_ view: V) {
        contentView = NSHostingView(rootView: view)
    }

    func fade(visible: Bool, duration: TimeInterval = 0.18) {
        if visible, !isVisible {
            alphaValue = 0
            orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            animator().alphaValue = visible ? 1 : 0
        }
    }
}

/// A short message near the top of the screen, shown above games. Dismisses itself.
@MainActor
enum Toast {
    private static var panel: FloatingPanel?
    private static var hideTask: Task<Void, Never>?

    static func show(_ message: String, symbol: String = "info.circle", seconds: Double = 4) {
        let panel = Self.panel ?? FloatingPanel(clickThrough: true)
        Self.panel = panel
        let view = HStack(spacing: 10) {
            Image(systemName: symbol).font(.title3)
            Text(message).font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.82), in: Capsule())
        .fixedSize()
        panel.host(view)
        let size = panel.contentView?.fittingSize ?? CGSize(width: 300, height: 44)
        let screen = NSScreen.underMouse ?? NSScreen.main!
        panel.setFrame(CGRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height - 60,
                              width: size.width, height: size.height), display: true)
        panel.fade(visible: true)
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            panel.fade(visible: false)
        }
    }
}
