import AppKit

/// Outline, grab bar and resize corner around the live region.
///
/// They fade out shortly after showing and come back only when the mouse *moves* near the region.
/// Position alone isn't enough: after dragging out the region the cursor stays parked on its corner
/// while you play with a controller.
@MainActor
final class RegionFrame {
    private static let barHeight: CGFloat = 26
    private static let handleSize: CGFloat = 16

    private(set) var region: CGRect
    var onChange: ((CGRect) -> Void)?
    var onClose: (() -> Void)?

    private let outline = FloatingPanel(clickThrough: true)
    private let bar = FloatingPanel(clickThrough: false)
    private let handle = FloatingPanel(clickThrough: false)
    private var watcher: Timer?
    private var lastMouse = NSEvent.mouseLocation
    private var lastActivity = Date()
    private var shown = true
    private var dragOrigin: CGRect = .zero

    init(region: CGRect) {
        self.region = region
        outline.contentView = OutlineView()
        let barView = DragView(kind: .move)
        barView.onBegin = { [weak self] in self?.dragOrigin = self?.region ?? .zero }
        barView.onDrag = { [weak self] dx, dy in self?.move(dx: dx, dy: dy) }
        barView.onClose = { [weak self] in self?.onClose?() }
        bar.contentView = barView
        let handleView = DragView(kind: .resize)
        handleView.onBegin = { [weak self] in self?.dragOrigin = self?.region ?? .zero }
        handleView.onDrag = { [weak self] dx, dy in self?.resize(dx: dx, dy: dy) }
        handle.contentView = handleView
        layout()
    }

    func show() {
        [outline, bar, handle].forEach { $0.orderFrontRegardless() }
        lastActivity = Date()
        lastMouse = NSEvent.mouseLocation
        watcher?.invalidate()
        watcher = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.watchMouse() }
        }
    }

    func close() {
        watcher?.invalidate()
        watcher = nil
        [outline, bar, handle].forEach { $0.orderOut(nil) }
    }

    private func layout() {
        outline.setFrame(region.insetBy(dx: -3, dy: -3), display: true)
        bar.setFrame(CGRect(x: region.minX, y: region.maxY + 4, width: 210, height: Self.barHeight), display: true)
        handle.setFrame(CGRect(x: region.maxX - Self.handleSize / 2, y: region.minY - Self.handleSize / 2,
                               width: Self.handleSize, height: Self.handleSize), display: true)
    }

    private func move(dx: CGFloat, dy: CGFloat) {
        region = dragOrigin.offsetBy(dx: dx, dy: dy)
        layout()
        onChange?(region)
    }

    private func resize(dx: CGFloat, dy: CGFloat) {
        let width = max(80, dragOrigin.width + dx)
        let height = max(24, dragOrigin.height - dy)
        region = CGRect(x: dragOrigin.minX, y: dragOrigin.maxY - height, width: width, height: height)
        layout()
        onChange?(region)
    }

    private func watchMouse() {
        let mouse = NSEvent.mouseLocation
        let moved = mouse != lastMouse
        lastMouse = mouse
        let nearby = region.union(bar.frame).insetBy(dx: -40, dy: -40).contains(mouse)
        if nearby, moved || NSEvent.pressedMouseButtons != 0 {
            lastActivity = Date()
            setShown(true)
        } else if Date().timeIntervalSince(lastActivity) > 2 {
            setShown(false)
        }
    }

    private func setShown(_ visible: Bool) {
        guard visible != shown else { return }
        shown = visible
        [outline, bar, handle].forEach { $0.fade(visible: visible) }
        // Hidden controls must not swallow clicks meant for the game.
        bar.ignoresMouseEvents = !visible
        handle.ignoresMouseEvents = !visible
    }
}

private final class OutlineView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 6, yRadius: 6)
        path.lineWidth = 2
        NSColor.systemTeal.setStroke()
        path.stroke()
    }
}

private final class DragView: NSView {
    enum Kind { case move, resize }

    let kind: Kind
    var onBegin: (() -> Void)?
    var onDrag: ((CGFloat, CGFloat) -> Void)?
    var onClose: (() -> Void)?
    private var anchor: CGPoint = .zero

    init(kind: Kind) {
        self.kind = kind
        super.init(frame: .zero)
        if kind == .move {
            let close = NSButton(image: NSImage(systemSymbolName: "xmark.circle.fill",
                                                accessibilityDescription: "Kapat") ?? NSImage(),
                                 target: self, action: #selector(closeTapped))
            close.isBordered = false
            close.contentTintColor = .white
            close.frame = CGRect(x: 184, y: 3, width: 22, height: 20)
            addSubview(close)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func closeTapped() { onClose?() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: kind == .move ? .openHand : .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        anchor = NSEvent.mouseLocation
        onBegin?()
    }

    override func mouseDragged(with event: NSEvent) {
        let point = NSEvent.mouseLocation
        onDrag?(point.x - anchor.x, point.y - anchor.y)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0.1, alpha: 0.9).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: kind == .move ? 7 : 4,
                     yRadius: kind == .move ? 7 : 4).fill()
        NSColor.systemTeal.setFill()
        if kind == .move {
            NSBezierPath(ovalIn: CGRect(x: 10, y: 10, width: 7, height: 7)).fill()
            ("SubLens · sürükle" as NSString).draw(at: CGPoint(x: 24, y: 6), withAttributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.white,
            ])
        } else {
            NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 4), xRadius: 2, yRadius: 2).fill()
        }
    }
}
