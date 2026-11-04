import UIKit
import SafariServices
import WebKit
import MixinServices

final class CustomerServiceViewController: PopupTitledWebViewController {
    
    private let context: MixinWebContext?
    private let presentLoginLogsOnLongPressingTitle: Bool
    private let reportingTags: [String: String]?
    
    private lazy var messageHandler = WebViewMessageHandler(delegate: self)
    
    init(
        context: MixinWebContext?,
        presentLoginLogsOnLongPressingTitle: Bool,
        reportingTags: [String: String]?
    ) {
        let url: URL
        if let context,
           var components = URLComponents(url: context.initialURL, resolvingAgainstBaseURL: true)
        {
            var queryItems: [URLQueryItem] = components.queryItems ?? []
            for item in context.additionalURLQueries {
                queryItems.append(URLQueryItem(name: item.key, value: item.value))
            }
            components.queryItems = queryItems
            url = components.url ?? context.initialURL
        } else {
            url = .customerService
        }
        
        self.context = context
        self.presentLoginLogsOnLongPressingTitle = presentLoginLogsOnLongPressingTitle
        self.reportingTags = reportingTags
        super.init(
            title: R.string.localizable.mixin_support(),
            subtitle: R.string.localizable.ask_me_anything(),
            url: url
        )
        Logger.general.debug(category: "CustomerService", message: "Init \(ObjectIdentifier(self))")
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    deinit {
        if let controller = webView?.configuration.userContentController {
            WebViewMessageHandler.Name.allCases.map(\.rawValue)
                .forEach(controller.removeScriptMessageHandler(forName:))
        }
        Logger.general.debug(category: "CustomerService", message: "Deinit \(ObjectIdentifier(self))")
    }
    
    static func invoke(
        presentLoginLogsOnLongPressingTitle: Bool = false,
        reportingTags: [String: String]?
    ) {
        _ = UrlWindow.checkApp(
            userID: BotUserID.mixinSafe,
            action: .customerService(
                presentLoginLogsOnLongPressingTitle: presentLoginLogsOnLongPressingTitle,
                reportingTags: reportingTags
            )
        )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let reportingTags {
            reporter.report(event: .customerServiceDialog, tags: reportingTags)
        }
        if presentLoginLogsOnLongPressingTitle {
            let presentLogRecognizer = UILongPressGestureRecognizer(
                target: self,
                action: #selector(presentLog(_:))
            )
            presentLogRecognizer.minimumPressDuration = 3
            titleView.addGestureRecognizer(presentLogRecognizer)
        }
    }
    
    override func replaceWebView(configuration: WKWebViewConfiguration) {
        if let configuration = webView?.configuration {
            WebViewMessageHandler.Name.allCases.map(\.rawValue)
                .forEach(configuration.userContentController.removeScriptMessageHandler(forName:))
        }
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        for name in WebViewMessageHandler.Name.allCases.map(\.rawValue) {
            configuration.userContentController.add(messageHandler, name: name)
        }
        configuration.applicationNameForUserAgent = MixinWebContext.applicationNameForUserAgent
        super.replaceWebView(configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }
    
    @objc private func presentLog(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            presentOnTopMostPresentedController(LoginLogViewController(), animated: true)
        default:
            break
        }
    }
    
}

extension CustomerServiceViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        let isPresented = presentingViewController != nil && !isBeingDismissed
        if let context, isPresented, (UrlWindow.checkUrl(url: url, from: .webView(context)) || UrlWindow.checkWithdrawal(string: url.absoluteString)) {
            decisionHandler(.cancel)
        } else if "file" == url.scheme {
            decisionHandler(.allow)
        } else if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            decisionHandler(.allow)
        } else if ["about:blank", "about:srcdoc"].contains(url.absoluteString.lowercased()) {
            decisionHandler(.allow)
        } else if isPresented {
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
    
}

extension CustomerServiceViewController: WKUIDelegate {
    
    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        if prompt == WebViewMessageHandler.Name.mixinContext.rawValue + ".getContext()", let context {
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
        // XXX: Remove those handlers to prevent app crash from adding it later
        WebViewMessageHandler.Name.allCases.map(\.rawValue)
            .forEach(configuration.userContentController.removeScriptMessageHandler(forName:))
        replaceWebView(configuration: configuration)
        return self.webView
    }
    
}

extension CustomerServiceViewController: WebViewMessageHandler.Delegate {
    
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
        case .getAssets(let assetIDs, let callback):
            DispatchQueue.global().async { [weak webView] in
                let tokens = TokenDAO.shared.appTokens(ids: assetIDs)
                if let data = try? JSONEncoder.default.encode(tokens), let string = String(data: data, encoding: .utf8) {
                    let assets = string.replacingOccurrences(of: "'", with: "\\'")
                    DispatchQueue.main.async {
                        webView?.evaluateJavaScript("\(callback)('\(assets)');")
                    }
                } else {
                    DispatchQueue.main.async {
                        webView?.evaluateJavaScript("\(callback)('[]');")
                    }
                }
            }
        case .web3Bridge:
            break
        case .signBotSignature(let callback):
            webView.evaluateJavaScript(callback)
        case .openInBrowser(let url):
            present(SFSafariViewController(url: url), animated: true)
        }
    }
    
    func webViewMessageHander(_ handler: WebViewMessageHandler, allowsSignBotWith appID: String) -> Bool {
        true
    }
    
    func webViewMessageHanderGetCurrentURL(_ handler: WebViewMessageHandler) -> URL? {
        webView.url
    }
    
}
