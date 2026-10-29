import SwiftUI
import WebKit

struct SignInView: View {
    @State private var showingWeb = false
    @State private var manual = false
    @State private var token = ""
    @State private var failed = false
    private var store: TrophyStore { .shared }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image("Mark").resizable().frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            VStack(spacing: 8) {
                Text("Tercana").font(.largeTitle.bold())
                Text(M.signInHint).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Button {
                failed = false
                showingWeb = true
            } label: {
                Text(S.signInWithPlayStation).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            if failed { Text(M.signInFailed).font(.footnote).foregroundStyle(.red) }
            if let problem = store.problem { Text(problem).font(.footnote).foregroundStyle(.red) }
            Spacer()
            DisclosureGroup(S.advancedManualToken, isExpanded: $manual) {
                HStack {
                    TextField(S.tokenPlaceholder, text: $token)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button(S.connect) { Task { await store.signIn(sessionToken: token) } }
                        .disabled(token.count < 20)
                }
                .padding(.top, 8)
            }
            .font(.footnote)
            Text(S.unofficialNote).font(.caption2).foregroundStyle(.tertiary).multilineTextAlignment(.center)
        }
        .padding(24)
        .sheet(isPresented: $showingWeb) {
            NavigationStack {
                PSNLoginWeb { result in
                    showingWeb = false
                    Task {
                        switch result {
                        case .code(let code): await store.signIn(authorizationCode: code)
                        case .token(let npsso): await store.signIn(sessionToken: npsso)
                        }
                        failed = !store.signedIn
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(S.signInWithPlayStation)
                .inlineTitle()
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(M.cancel) { showingWeb = false } } }
            }
        }
    }
}

/// Sony's sign-in page; finishes on the OAuth redirect code, or on the npsso cookie as a fallback.
struct PSNLoginWeb: UIViewRepresentable {
    enum Result { case code(String), token(String) }
    let done: (Result) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.load(URLRequest(url: PSNClient.authorizeURL))
        context.coordinator.web = web
        return web
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var done: ((Result) -> Void)?
        weak var web: WKWebView?

        init(done: @escaping (Result) -> Void) { self.done = done }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url, url.scheme == PSNClient.redirectScheme else {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
            let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "code" }?.value
            if let code { finish(.code(code)) }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                MainActor.assumeIsolated {
                    if let token = cookies.first(where: { $0.name == "npsso" && !$0.value.isEmpty })?.value {
                        self.finish(.token(token))
                    }
                }
            }
        }

        private func finish(_ result: Result) {
            guard let done else { return }
            self.done = nil
            done(result)
        }
    }
}
