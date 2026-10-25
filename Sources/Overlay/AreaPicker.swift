import AppKit

/// Full-screen dimmed layer for dragging out a rectangle. Esc or a click without dragging cancels.
@MainActor
final class AreaPicker {
    private var window: NSWindow?
    private var completion: ((CGRect?) -> Void)?

    /// Calls back with the chosen rectangle in global AppKit coordinates, or nil when cancelled.
    func pick(hint: String, completion: @escaping (CGRect?) -> Void) {
        guard window == nil, let screen = NSScreen.underMouse else { return completion(nil) }
        self.completion = completion
        let window = KeyableWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        let view = PickerView(hint: hint) { [weak self] localRect in
            guard let self else { return }
            let global = localRect.map { $0.offsetBy(dx: screen.frame.minX, dy: screen.frame.minY) }
            self.finish(global)
        }
        window.contentView = view
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        NSCursor.crosshair.push()
    }

    private func finish(_ rect: CGRect?) {
        NSCursor.pop()
        window?.orderOut(nil)
        window = nil
        let completion = self.completion
        self.completion = nil
        completion?(rect)
    }
}

/// Borderless windows can't take key status by default, which would leave Esc unhandled.
private final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

private final class PickerView: NSView {
    private let hint: String
    private let onDone: (CGRect?) -> Void
    private var start: CGPoint?
    private var current: CGPoint?

    init(hint: String, onDone: @escaping (CGRect?) -> Void) {
        self.hint = hint
        self.onDone = onDone
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var selection: CGRect? {
        guard let start, let current else { return nil }
        return CGRect(x: min(start.x, current.x), y: min(start.y, current.y),
                      width: abs(start.x - current.x), height: abs(start.y - current.y))
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.35).setFill()
        bounds.fill()
        if let selection {
            NSColor.clear.setFill()
            selection.fill(using: .copy)
            let border = NSBezierPath(rect: selection.insetBy(dx: -1, dy: -1))
            border.lineWidth = 2
            NSColor.systemTeal.setStroke()
            border.stroke()
        } else {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: NSColor.white,
            ]
            let text = hint as NSString
            let size = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
                      withAttributes: attributes)
        }
    }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        current = start
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        if let selection, selection.width >= 20, selection.height >= 12 {
            onDone(selection)
        } else {
            onDone(nil)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onDone(nil) }  // Esc
    }
}
