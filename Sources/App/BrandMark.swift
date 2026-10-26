import AppKit

/// The SubLens mark: a lens with two subtitle lines inside. Drawn in code so the app icon and the
/// menu bar icon are the same shape.
enum BrandMark {
    /// Draws the mark into `rect`. `lineColors` colours the two subtitle lines (top, bottom).
    static func draw(in rect: CGRect, stroke: NSColor, lineColors: (NSColor, NSColor), lineWidthScale: CGFloat = 1) {
        let s = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - s / 2, y: rect.midY - s / 2)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: origin.x + x * s, y: origin.y + y * s) }

        if lineWidthScale > 0 {
        let ring = NSBezierPath(ovalIn: CGRect(origin: p(0.08, 0.30), size: CGSize(width: 0.62 * s, height: 0.62 * s)))
        ring.lineWidth = 0.085 * s * lineWidthScale
        stroke.setStroke()
        ring.stroke()

        let handle = NSBezierPath()
        handle.move(to: p(0.62, 0.36))
        handle.line(to: p(0.90, 0.08))
        handle.lineWidth = 0.12 * s * lineWidthScale
        handle.lineCapStyle = .round
        handle.stroke()
        }

        lineColors.0.setFill()
        NSBezierPath(roundedRect: CGRect(origin: p(0.22, 0.64), size: CGSize(width: 0.34 * s, height: 0.075 * s)),
                     xRadius: 0.04 * s, yRadius: 0.04 * s).fill()
        lineColors.1.setFill()
        NSBezierPath(roundedRect: CGRect(origin: p(0.17, 0.50), size: CGSize(width: 0.44 * s, height: 0.075 * s)),
                     xRadius: 0.04 * s, yRadius: 0.04 * s).fill()
    }

    /// Template image for the menu bar; `live` fills the lens so the state shows at a glance.
    static func menuBarImage(live: Bool) -> NSImage {
        let image = NSImage(size: CGSize(width: 18, height: 18), flipped: false) { rect in
            draw(in: rect, stroke: .black, lineColors: (.black, .black), lineWidthScale: 1.1)
            guard live else { return true }
            // Live: a solid lens with the subtitle lines cut out of it.
            NSColor.black.setFill()
            NSBezierPath(ovalIn: CGRect(x: 1.44, y: 5.4, width: 11.16, height: 11.16)).fill()
            NSGraphicsContext.current?.compositingOperation = .clear
            draw(in: rect, stroke: .clear, lineColors: (.black, .black), lineWidthScale: 0)
            return true
        }
        image.isTemplate = true
        return image
    }
}
