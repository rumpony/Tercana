import AppKit
import ScreenCaptureKit

enum ScreenGrabberError: LocalizedError {
    case noPermission
    case displayNotFound

    var errorDescription: String? {
        switch self {
        case .noPermission: return "Ekran kaydı izni yok. Sistem Ayarları → Gizlilik ve Güvenlik → Ekran Kaydı'ndan SubLens'i aç."
        case .displayNotFound: return "Seçilen alanın bulunduğu ekran bulunamadı."
        }
    }
}

/// Captures a rectangle of the screen, leaving SubLens' own windows out of the image
/// so the overlay never ends up in what we read.
@MainActor
final class ScreenGrabber {
    static let shared = ScreenGrabber()

    private var cachedFilters: [CGDirectDisplayID: SCContentFilter] = [:]

    static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    static func requestPermission() {
        CGRequestScreenCaptureAccess()
    }

    /// `rect` is in global AppKit coordinates (origin bottom-left of the main display).
    func capture(_ rect: CGRect) async throws -> CGImage {
        guard Self.hasPermission else { throw ScreenGrabberError.noPermission }
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(rect) }),
              let displayID = screen.displayID else { throw ScreenGrabberError.displayNotFound }

        let filter = try await filter(for: displayID)
        let config = SCStreamConfiguration()
        let local = CGRect(x: rect.minX - screen.frame.minX,
                           y: screen.frame.maxY - rect.maxY,
                           width: rect.width, height: rect.height)
        config.sourceRect = local
        config.width = Int(local.width * screen.backingScaleFactor)
        config.height = Int(local.height * screen.backingScaleFactor)
        config.showsCursor = false
        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            // The cached filter goes stale when displays or our windows change; retry once with a fresh one.
            cachedFilters[displayID] = nil
            let fresh = try await self.filter(for: displayID)
            return try await SCScreenshotManager.captureImage(contentFilter: fresh, configuration: config)
        }
    }

    private func filter(for displayID: CGDirectDisplayID) async throws -> SCContentFilter {
        if let cached = cachedFilters[displayID] { return cached }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw ScreenGrabberError.displayNotFound
        }
        let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        cachedFilters[displayID] = filter
        return filter
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    static var underMouse: NSScreen? {
        let point = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(point, $0.frame, false) } ?? main
    }
}
