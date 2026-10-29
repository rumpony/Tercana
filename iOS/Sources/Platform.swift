import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// The few places where the phone and the Mac need different calls; screens stay the same.
extension View {
    func inlineTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    func compactSections() -> some View {
        #if os(iOS)
        listSectionSpacing(.compact)
        #else
        self
        #endif
    }

    func pagedTabs() -> some View {
        #if os(iOS)
        tabViewStyle(.page(indexDisplayMode: .always))
        #else
        self
        #endif
    }

    /// Full screen on the phone, a sheet on the Mac.
    func cover<Item: Identifiable, V: View>(item: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> V) -> some View {
        #if os(iOS)
        fullScreenCover(item: item, content: content)
        #else
        sheet(item: item, content: content)
        #endif
    }
}

enum Haptic {
    @MainActor static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    @MainActor static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

/// Opens a link in the system browser, outside the app.
@MainActor
func openExternally(_ url: URL) {
    #if os(iOS)
    UIApplication.shared.open(url)
    #else
    NSWorkspace.shared.open(url)
    #endif
}

/// Renders a view to an image that ShareLink can send. Artwork must already be cached to show up.
@MainActor
func snapshot(_ view: some View) -> Image {
    let renderer = ImageRenderer(content: view)
    renderer.scale = 3
    #if os(iOS)
    return renderer.uiImage.map(Image.init(uiImage:)) ?? Image(systemName: "photo")
    #else
    return renderer.nsImage.map(Image.init(nsImage:)) ?? Image(systemName: "photo")
    #endif
}
