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

/// A small banner that slides down from the top edge and offers a choice.
/// It doesn't take focus from the game; it closes itself after a while.
@MainActor
enum Prompt {
    typealias Action = (title: String, primary: Bool, run: () -> Void)

    private static var panel: FloatingPanel?
    private static var hideTask: Task<Void, Never>?

    static func show(_ message: String, hint: String, actions: [Action], seconds: Double = 15) {
        let panel = Self.panel ?? FloatingPanel(clickThrough: false)
        Self.panel = panel
        panel.host(PromptView(message: message, hint: hint, actions: actions) { dismiss() })
        let size = panel.contentView?.fittingSize ?? CGSize(width: 480, height: 64)
        let screen = NSScreen.underMouse ?? NSScreen.main!
        let shown = CGRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height - 44,
                           width: size.width, height: size.height)
        panel.setFrame(shown.offsetBy(dx: 0, dy: 40), display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(shown, display: true)
            panel.animator().alphaValue = 1
        }
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    static func dismiss() {
        hideTask?.cancel()
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().setFrame(panel.frame.offsetBy(dx: 0, dy: 30), display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated { panel.orderOut(nil) }
        })
    }
}

struct PromptView: View {
    let message: String
    let hint: String
    let actions: [Prompt.Action]
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "captions.bubble.fill").font(.title2).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(message).font(.system(size: 14, weight: .semibold))
                Text(hint).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                if action.primary {
                    Button(action.title) { onClose(); action.run() }.buttonStyle(.borderedProminent)
                } else {
                    Button(action.title) { onClose(); action.run() }
                }
            }
            Button { onClose() } label: { Image(systemName: "xmark").font(.caption.weight(.bold)) }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minWidth: 460)
        .fixedSize()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }
}
