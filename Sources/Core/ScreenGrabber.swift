import AppKit
import ScreenCaptureKit

enum ScreenGrabberError: LocalizedError {
    case noPermission
    case displayNotFound

    var errorDescription: String? {
        switch self {
        case .noPermission: return S.errorNoPermission
        case .displayNotFound: return S.errorNoDisplay
        }
    }
}

/// Captures a rectangle of the screen, leaving Tercana' own windows out of the image
/// so the overlay never ends up in what we read.
@MainActor
final class ScreenGrabber {
    static let shared = ScreenGrabber()

    private var cachedFilters: [CGDirectDisplayID: SCContentFilter] = [:]
    /// The Remote Play / Chiaki window, when one is open, with when it was looked up.
    private var streamWindow: (window: SCWindow, filter: SCContentFilter, found: Date)?
    private var lastWindowLookup = Date.distantPast
    /// Whether the last capture came from the stream window rather than the screen.
    private(set) var lastFromWindow = false

    static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    static func requestPermission() {
        CGRequestScreenCaptureAccess()
    }

    /// Forget cached filters, e.g. when a live session starts or displays change.
    func reset() {
        cachedFilters.removeAll()
        streamWindow = nil
        lastWindowLookup = .distantPast
    }

    /// `rect` is in global AppKit coordinates (origin bottom-left of the main display).
    func capture(_ rect: CGRect) async throws -> CGImage {
        guard Self.hasPermission else { throw ScreenGrabberError.noPermission }
        // Read the stream window itself when the area lies on it: works while the game is full screen on
        // another desktop, and nothing in front of it (a terminal, a browser) ends up in the image.
        do {
            if let image = try await captureStreamWindow(rect) { lastFromWindow = true; return image }
        } catch {
            NSLog("Tercana window capture: %@", String(describing: error))
        }
        lastFromWindow = false
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

    private func captureStreamWindow(_ rect: CGRect) async throws -> CGImage? {
        if streamWindow == nil || Date().timeIntervalSince(streamWindow!.found) > 10 {
            guard Date().timeIntervalSince(lastWindowLookup) > 3 else { return nil }
            lastWindowLookup = Date()
            streamWindow = nil
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            let candidates = content.windows.filter {
                RemotePlayWatcher.bundleIDs.contains($0.owningApplication?.bundleIdentifier ?? "")
                    && $0.windowLayer == 0 && $0.frame.width > 400 && $0.frame.height > 300
            }
            guard let window = candidates.max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height })
            else { NSLog("Tercana window capture: no stream window (%d windows)", content.windows.count); return nil }
            NSLog("Tercana window capture: using %@ %@", window.owningApplication?.bundleIdentifier ?? "?", NSStringFromRect(window.frame))
            streamWindow = (window, SCContentFilter(desktopIndependentWindow: window), Date())
        }
        guard let (window, filter, _) = streamWindow else { return nil }
        // SCWindow.frame is top-left based on the main display; `rect` is AppKit (bottom-left).
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let flipped = CGRect(x: rect.minX, y: mainHeight - rect.maxY, width: rect.width, height: rect.height)
        let frame = window.frame
        // A full-screen window on another desktop has the display's frame, so the saved area still maps onto it.
        guard frame.intersection(flipped).width * frame.intersection(flipped).height
                > 0.8 * flipped.width * flipped.height else {
            NSLog("Tercana window capture: area %@ outside window %@", NSStringFromRect(flipped), NSStringFromRect(frame))
            return nil
        }
        let scale = NSScreen.screens.first(where: { $0.frame.intersects(rect) })?.backingScaleFactor ?? 2
        let config = SCStreamConfiguration()
        config.sourceRect = CGRect(x: flipped.minX - frame.minX, y: flipped.minY - frame.minY,
                                   width: flipped.width, height: flipped.height)
        config.width = Int(flipped.width * scale)
        config.height = Int(flipped.height * scale)
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            NSLog("Tercana window capture failed: %@", String(describing: error))
            streamWindow = nil
            return nil
        }
    }

    private func filter(for displayID: CGDirectDisplayID) async throws -> SCContentFilter {
        if let cached = cachedFilters[displayID] { return cached }
        // Ask for all windows, not just on-screen ones: with only on-screen windows Tercana is
        // missing from the list whenever it has nothing showing yet, the exclusion silently
        // becomes empty, and the translation overlay later gets read back as a subtitle.
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw ScreenGrabberError.displayNotFound
        }
        let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        guard !ownApps.isEmpty else { throw ScreenGrabberError.displayNotFound }
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
