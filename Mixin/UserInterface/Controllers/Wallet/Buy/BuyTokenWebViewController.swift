import UIKit
import WebKit
import MixinServices

final class BuyTokenWebViewController: PopupTitledWebViewController {
    
    private let context: MixinWebContext
    
    private var isMessageHandlerAdded = true
    
    private lazy var messageHandler = WebViewMessageHandler(delegate: self)
    
    init(tokenSymbol: String, url: URL) {
        self.context = MixinWebContext(conversationId: "", initialUrl: url)
        super.init(
            title: R.string.localizable.buy_asset(tokenSymbol),
            subtitle: nil,
            url: url
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    deinit {
        Logger.general.debug(category: "BuyToken", message: "WebViewController deinited")
    }
    
    override func replaceWebView(configuration: WKWebViewConfiguration) {
        configuration.allowsInlineMediaPlayback = true
        for name in WebViewMessageHandler.Name.allCases.map(\.rawValue) {
            configuration.userContentController.add(messageHandler, name: name)
        }
        configuration.applicationNameForUserAgent = MixinWebContext.applicationNameForUserAgent
        super.replaceWebView(configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !isMessageHandlerAdded {
            for name in WebViewMessageHandler.Name.allCases.map(\.rawValue) {
                webView.configuration.userContentController.add(messageHandler, name: name)
            }
            isMessageHandlerAdded = true
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let webView, isMessageHandlerAdded {
            let controller = webView.configuration.userContentController
            WebViewMessageHandler.Name.allCases.map(\.rawValue)
                .forEach(controller.removeScriptMessageHandler(forName:))
            isMessageHandlerAdded = false
        }
    }
    
}

extension BuyTokenWebViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if isViewLoaded && (UrlWindow.checkUrl(url: url, from: .webView(context)) || UrlWindow.checkWithdrawal(string: url.absoluteString)) {
            decisionHandler(.cancel)
        } else if "file" == url.scheme {
            decisionHandler(.allow)
        } else if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            decisionHandler(.allow)
        } else if ["about:blank", "about:srcdoc"].contains(url.absoluteString.lowercased()) {
            decisionHandler(.allow)
        } else if parent != nil {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
        } else if parent == nil, let url = MixinURL(url: url), case .codes(let code) = url {
            // Call `AuthorizeAPI.authorize` with an empty scope will cancel the auth request
            // Cancel the request when webview is not visible, mostly because user has chosen to close it
            UserAPI.codes(codeId: code) { (result) in
                switch result {
                case let .success(code):
                    if let auth = code.authorization {
                        AuthorizeAPI.authorize(authorizationId: auth.authorizationId, scopes: [], pin: nil) { _ in }
                    }
                case .failure:
                    break
                }
            }
            decisionHandler(.cancel)
        } else {
            decisionHandler(.cancel)
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }
    
}

extension BuyTokenWebViewController: WKUIDelegate {
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        if prompt == WebViewMessageHandler.Name.mixinContext.rawValue + ".getContext()" {
            completionHandler(context.appContextString)
        } else {
            completionHandler("")
        }
    }
    
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        for name in WebViewMessageHandler.Name.allCases.map(\.rawValue) {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: name)
        }
        replaceWebView(configuration: configuration)
        self.webView.load(navigationAction.request)
        return nil
    }
    
}

extension BuyTokenWebViewController: WebViewMessageHandler.Delegate {
    
    func webViewMessageHander(_ handler: WebViewMessageHandler, didReceiveMessage message: WebViewMessageHandler.Message) {
        switch message {
        case .reloadTheme:
            break
        case .close:
            presentingViewController?.dismiss(animated: true)
        case .getTIPAddress(let callback):
            webView.evaluateJavaScript(callback)
        case .tipSign(let callback):
            webView.evaluateJavaScript(callback)
        case .getAssets(_, let callback):
            webView.evaluateJavaScript("\(callback)('[]');")
        case .web3Bridge:
            break
        case .signBotSignature(let callback):
            webView.evaluateJavaScript(callback)
        }
    }
    
    func webViewMessageHanderGetCurrentURL(_ handler: WebViewMessageHandler) -> URL? {
        webView.url
    }
    
}
