import SwiftUI
import WebKit

/// 单个远程会话页面：加载官方 /remote/v4 页面。
/// 登录态由共享 WKWebsiteDataStore 维护——登录一次，所有会话可用。
struct SessionView: View {
    let session: RemoteSession
    @EnvironmentObject var store: SessionStore

    var body: some View {
        RemoteWebView(urlString: session.urlString)
            .ignoresSafeArea()
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { store.touch(session) }
    }
}

struct RemoteWebView: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
