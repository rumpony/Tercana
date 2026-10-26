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
        // Sony's sign-in rejects unknown embedded browsers; present as Safari.
        web.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
        web.load(URLRequest(url: PSNClient.signInURL))

        let header = NSHostingView(rootView: LoginHeader())
        let stack = NSStackView(views: [header, web])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .width
        // A web view has no natural size; without these it collapses to nothing inside the stack.
        web.translatesAutoresizingMaskIntoConstraints = false
        web.setContentHuggingPriority(.defaultLow, for: .vertical)
        web.heightAnchor.constraint(greaterThanOrEqualToConstant: 560).isActive = true
        header.setContentHuggingPriority(.required, for: .vertical)
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

    /// Looks for the session token two ways: the `npsso` cookie itself, and — since Sony doesn't
    /// always expose it to the web view — by asking the token endpoint with the window's cookies,
    /// which is exactly what the manual method does in a browser. The visible page is left alone.
    private func checkCookie() {
        guard !asking else { return }
        webView?.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let token = cookies.first(where: { $0.name == "npsso" && !$0.value.isEmpty })?.value {
                    self.finish(token)
                    return
                }
                let sony = cookies.filter { $0.domain.hasSuffix("sony.com") }
                guard !sony.isEmpty else { return }
                self.asking = true
                var request = URLRequest(url: PSNClient.sessionTokenURL)
                request.setValue(sony.map { "\($0.name)=\($0.value)" }.joined(separator: "; "), forHTTPHeaderField: "Cookie")
                Task {
                    defer { self.asking = false }
                    guard let (data, _) = try? await URLSession.shared.data(for: request),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let token = json["npsso"] as? String, !token.isEmpty else { return }
                    self.finish(token)
                }
            }
        }
    }

    private var asking = false

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
