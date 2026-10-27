// Renders the app icon from BrandMark. Usage: Tools/Icon/run.sh
import AppKit
let out = CommandLine.arguments[1]
let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let body = NSBezierPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
NSGradient(starting: NSColor(calibratedRed: 0.05, green: 0.36, blue: 0.40, alpha: 1),
           ending: NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.30, alpha: 1))!.draw(in: body, angle: -70)
BrandMark.draw(in: CGRect(x: 262, y: 262, width: 500, height: 500),
               top: NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.27, alpha: 1), stem: .white)
NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
