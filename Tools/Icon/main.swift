// Renders the app icon from BrandMark. Usage: Tools/Icon/run.sh
import AppKit
let out = CommandLine.arguments[1]
let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let body = NSBezierPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
NSGradient(starting: NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.20, alpha: 1),
           ending: NSColor(calibratedRed: 0.27, green: 0.16, blue: 0.45, alpha: 1))!.draw(in: body, angle: -60)
BrandMark.draw(in: CGRect(x: 232, y: 232, width: 560, height: 560),
               stroke: NSColor(calibratedRed: 0.45, green: 0.85, blue: 0.95, alpha: 1),
               lineColors: (.white, NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.30, alpha: 1)))
NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
