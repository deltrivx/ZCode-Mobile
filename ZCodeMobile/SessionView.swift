import SwiftUI
import WebKit

/// 单个远程会话页面：加载官方 /remote/v4 页面。
/// 登录态由共享 WKWebsiteDataStore 维护——登录一次，所有会话可用。
/// 官方页面的「通过浏览器授权登录」通过 window.open 弹出 OAuth 窗口；
/// WKWebView 默认拦截弹窗，这里捕获后转成应用内授权浮层完成登录。
struct SessionView: View {
    let session: RemoteSession
    @EnvironmentObject var store: SessionStore
    @State private var popupRequest: PopupRequest?
    @State private var reloadToken = 0

    var body: some View {
        RemoteWebView(urlString: session.urlString,
                      popupRequest: $popupRequest,
                      reloadToken: $reloadToken)
            .ignoresSafeArea()
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { store.touch(session) }
            .sheet(item: $popupRequest) { request in
                AuthPopupView(popupURL: request.url) {
                    reloadToken += 1
                }
            }
    }
}

struct PopupRequest: Identifiable {
    let id = UUID()
    let url: URL
}

struct RemoteWebView: UIViewRepresentable {
    let urlString: String
    @Binding var popupRequest: PopupRequest?
    @Binding var reloadToken: Int

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.uiDelegate = context.coordinator
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if context.coordinator.appliedReloadToken != reloadToken {
            context.coordinator.appliedReloadToken = reloadToken
            uiView.reload()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(popupRequest: $popupRequest)
    }

    final class Coordinator: NSObject, WKUIDelegate {
        let popupRequest: Binding<PopupRequest?>
        var appliedReloadToken = 0

        init(popupRequest: Binding<PopupRequest?>) {
            self.popupRequest = popupRequest
        }

        /// 官方页面的 window.open 弹窗 → 转为应用内浮层加载
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard let url = navigationAction.request.url else { return nil }
            DispatchQueue.main.async {
                self.popupRequest.wrappedValue = PopupRequest(url: url)
            }
            return nil
        }
    }
}

/// 应用内授权浮层：与主页面共享 WKWebsiteDataStore，
/// 授权完成后（页面跳回 /remote/ 路径，或手动点「完成」）关闭并刷新主页面。
struct AuthPopupView: View {
    let popupURL: URL
    let onFinish: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AuthPopupWebView(url: popupURL, onAuthComplete: {
                dismiss()
                onFinish()
            })
            .ignoresSafeArea()
            .navigationTitle("登录授权")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                        onFinish()
                    }
                }
            }
        }
    }
}

struct AuthPopupWebView: UIViewRepresentable {
    let url: URL
    let onAuthComplete: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onAuthComplete: onAuthComplete) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onAuthComplete: () -> Void
        private var notified = false

        init(onAuthComplete: @escaping () -> Void) {
            self.onAuthComplete = onAuthComplete
        }

        /// 授权成功后官方页面会跳回 /remote/ 路径——关闭浮层并刷新主页面
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               let host = url.host, host.hasSuffix("zcode.z.ai"),
               url.path.contains("/remote/"),
               !notified {
                notified = true
                DispatchQueue.main.async { [onAuthComplete] in
                    onAuthComplete()
                }
            }
            decisionHandler(.allow)
        }
    }
}
