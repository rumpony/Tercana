import AppKit
import SwiftUI
import WebKit

/// Sony's own sign-in page inside the app. Once the account cookie appears we hand it to the
/// PSN client and close; the web session is private to this window and thrown away afterwards.
@MainActor
final class PSNWebLogin: NSObject, WKNavigationDelegate {
    static let shared = PSNWebLogin()

    private var window: NSWindow?
    private var webView: WKWebView?
    private var poll: Timer?
    private var onToken: ((String) -> Void)?

    func begin(onToken: @escaping (String) -> Void) {
        self.onToken = onToken
        if let window { window.makeKeyAndOrderFront(nil); return }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.load(URLRequest(url: PSNClient.signInURL))

        let header = NSHostingView(rootView: LoginHeader())
        let stack = NSStackView(views: [header, web])
        stack.orientation = .vertical
        stack.spacing = 0
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 520, height: 720),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = S.signInWithPlayStation
        window.contentView = stack
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        self.webView = web
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)

        // Some sign-in steps finish inside scripts without a navigation event; check now and then too.
        poll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkCookie() }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        checkCookie()
    }

    private func checkCookie() {
        webView?.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let token = cookies.first(where: { $0.name == "npsso" && !$0.value.isEmpty })?.value else { return }
            MainActor.assumeIsolated { self?.finish(token) }
        }
    }

    private func finish(_ token: String) {
        guard let onToken else { return }
        self.onToken = nil
        poll?.invalidate()
        poll = nil
        window?.close()
        window = nil
        webView = nil
        onToken(token)
    }
}

private struct LoginHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield").foregroundStyle(.tint)
            Text(S.webLoginHint).font(.callout)
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}
