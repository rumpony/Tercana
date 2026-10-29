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

extension View {
    /// Glass buttons on the phone; on the Mac a quiet rounded fill, since Mac glass buttons
    /// come out as loud solid bars.
    @ViewBuilder
    func softButton(prominent: Bool = false) -> some View {
        #if os(iOS)
        if prominent { buttonStyle(.glassProminent) } else { buttonStyle(.glass) }
        #else
        buttonStyle(SoftButtonStyle(prominent: prominent))
        #endif
    }

    /// Close control for sheets: a toolbar button on the phone, a small round button in the
    /// corner on the Mac (where sheet toolbars become a bottom bar).
    func closeButton(_ action: @escaping () -> Void) -> some View {
        #if os(iOS)
        toolbar { Button(S.close, action: action) }
        #else
        overlay(alignment: .topTrailing) {
            Button(action: action) {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                    .frame(width: 26, height: 26)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .padding(14)
        }
        .frame(minWidth: 460, minHeight: 520)
        #endif
    }
}

struct SoftButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(prominent ? Style.glow.opacity(0.35) : Color.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.08)))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
