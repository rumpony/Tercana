import AppKit

/// The Tercana mark: a "T" built from two subtitle bars — the wide top bar is the translated line,
/// the stem is the original. Drawn in code so the app icon and the menu bar icon always match.
enum BrandMark {
    static func draw(in rect: CGRect, top: NSColor, stem: NSColor) {
        let s = min(rect.width, rect.height)
        let o = CGPoint(x: rect.midX - s / 2, y: rect.midY - s / 2)
        func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: o.x + x * s, y: o.y + y * s, width: w * s, height: h * s)
        }
        top.setFill()
        NSBezierPath(roundedRect: r(0.10, 0.66, 0.80, 0.17), xRadius: 0.085 * s, yRadius: 0.085 * s).fill()
        stem.setFill()
        NSBezierPath(roundedRect: r(0.415, 0.12, 0.17, 0.46), xRadius: 0.085 * s, yRadius: 0.085 * s).fill()
    }

    /// Template image for the menu bar; `live` turns it into a solid tile with the T cut out.
    static func menuBarImage(live: Bool) -> NSImage {
        let image = NSImage(size: CGSize(width: 18, height: 18), flipped: false) { rect in
            if live {
                NSColor.black.setFill()
                NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4).fill()
                NSGraphicsContext.current?.compositingOperation = .clear
                draw(in: rect.insetBy(dx: 4, dy: 4), top: .black, stem: .black)
            } else {
                draw(in: rect.insetBy(dx: 1.5, dy: 1.5), top: .black, stem: .black)
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
