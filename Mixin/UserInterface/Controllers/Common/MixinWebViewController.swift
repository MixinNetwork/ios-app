import UIKit
import WebKit
import Alamofire
import MixinServices

class MixinWebViewController: WebViewController {
    
    private enum HandlerName {
        static let mixinContext = "MixinContext"
        static let reloadTheme = "reloadTheme"
    }
    
    private let loadingIndicator = AppLoadingIndicatorView(frame: .zero)
    
    override var config: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = .all
        config.preferences = WKPreferences()
        config.preferences.minimumFontSize = 12
        config.preferences.javaScriptEnabled = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .video
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.userContentController.addUserScript(Script.disableImageSelection)
        config.userContentController.add(self, name: HandlerName.mixinContext)
        config.userContentController.add(self, name: HandlerName.reloadTheme)
        return config
    }
    
    private var context: Context!
    private var webViewTitleObserver: NSKeyValueObservation?
    
    class func presentInstance(with context: Context, asChildOf parent: UIViewController) {
        let vc = MixinWebViewController(nib: R.nib.webView)
        vc.context = context
        vc.view.frame = parent.view.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        parent.addChild(vc)
        parent.view.addSubview(vc.view)
        vc.didMove(toParent: parent)
        
        vc.view.center.y = parent.view.bounds.height * 3 / 2
        UIView.animate(withDuration: 0.5) {
            UIView.setAnimationCurve(.overdamped)
            vc.view.center.y = parent.view.bounds.height / 2
        }
        
        AppDelegate.current.window.endEditing(true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        contentView.addSubview(loadingIndicator)
        loadingIndicator.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
        }
        loadingIndicator.startAnimating()
        showPageTitleConstraint.priority = context.isImmersive ? .defaultLow : .defaultHigh
        switch context.style {
        case .webPage:
            webViewTitleObserver = webView.observe(\.title, options: [.initial, .new], changeHandler: { [weak self] (webView, _) in
                guard let weakSelf = self, case .webPage = weakSelf.context.style else {
                    return
                }
                self?.titleLabel.text = webView.title
            })
        case let .app(_, title, iconUrl):
            titleLabel.text = title
            if let iconUrl = iconUrl {
                titleImageView.isHidden = false
                titleImageView.sd_setImage(with: iconUrl, completed: nil)
            }
        }
        webView.navigationDelegate = self
        webView.uiDelegate = self
        let request = URLRequest(url: context.initialUrl)
        webView.load(request)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: HandlerName.mixinContext)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: HandlerName.reloadTheme)
    }
    
    override func moreAction(_ sender: Any) {
        let currentUrl = webView.url ?? .blank
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        switch context.style {
        case .app:
            controller.addAction(UIAlertAction(title: R.string.localizable.setting_about(), style: .default, handler: { (_) in
                self.aboutAction()
            }))
            
            controller.addAction(UIAlertAction(title: Localized.ACTION_REFRESH, style: .default, handler: { (_) in
                let request = URLRequest(url: currentUrl,
                                         cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                         timeoutInterval: 10)
                self.webView.load(request)
            }))
        case .webPage:
            controller.addAction(UIAlertAction(title: R.string.localizable.action_share(), style: .default, handler: { (_) in
                self.shareUrlAction(currentUrl: currentUrl)
            }))
            controller.addAction(UIAlertAction(title: R.string.localizable.group_button_title_copy_link(), style: .default, handler: { (_) in
                self.copyAction(currentUrl: currentUrl)
            }))
            controller.addAction(UIAlertAction(title: Localized.ACTION_REFRESH, style: .default, handler: { (_) in
                let request = URLRequest(url: currentUrl,
                                         cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                         timeoutInterval: 10)
                self.webView.load(request)
            }))
            controller.addAction(UIAlertAction(title: Localized.ACTION_OPEN_SAFARI, style: .default, handler: { (_) in
                UIApplication.shared.open(currentUrl, options: [:], completionHandler: nil)
            }))
        }
        
        controller.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        present(controller, animated: true, completion: nil)
    }
    
}

extension MixinWebViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if UrlWindow.checkUrl(url: url, fromWeb: true) {
            decisionHandler(.cancel)
            return
        } else if "file" == url.scheme {
            decisionHandler(.allow)
            return
        }
        
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard !loadingIndicator.isHidden else {
            return
        }
        loadingIndicator.stopAnimating()
        loadingIndicator.isHidden = true
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        reloadTheme(webView: webView)
    }
    
}

extension MixinWebViewController: WKUIDelegate {
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        if prompt == HandlerName.mixinContext + ".getContext()" {
            completionHandler(context.appContextString)
        } else {
            completionHandler("")
        }
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if !(navigationAction.targetFrame?.isMainFrame ?? false) {
            webView.load(navigationAction.request)
        }
        return nil
    }
    
}

extension MixinWebViewController: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == HandlerName.reloadTheme {
            reloadTheme(webView: webView)
        }
    }
    
}

extension MixinWebViewController {
    
    private func reloadTheme(webView: WKWebView) {
        webView.evaluateJavaScript(Script.getThemeColor) { [weak self] (result, error) in
            guard let colorString = result as? String else {
                return
            }
            let color = UIColor(hexString: colorString) ?? .background
            self?.updateBackground(pageThemeColor: color)
        }
    }
    
    private func aboutAction() {
        guard case let .app(appId, _, _) = context.style else {
            return
        }
        DispatchQueue.global().async {
            var userItem = UserDAO.shared.getUser(userId: appId)
            var updateUserFromRemoteAfterReloaded = true
            
            if userItem == nil, case let .success(response) = UserAPI.shared.showUser(userId: appId) {
                updateUserFromRemoteAfterReloaded = false
                userItem = UserItem.createUser(from: response)
                UserDAO.shared.updateUsers(users: [response])
            }
            
            guard let user = userItem else {
                return
            }
            DispatchQueue.main.async {
                let vc = UserProfileViewController(user: user)
                vc.updateUserFromRemoteAfterReloaded = updateUserFromRemoteAfterReloaded
                UIApplication.homeContainerViewController?.present(vc, animated: true, completion: nil)
            }
        }
    }
    
    private func copyAction(currentUrl: URL) {
        UIPasteboard.general.string = currentUrl.absoluteString
        showAutoHiddenHud(style: .notification, text: Localized.TOAST_COPIED)
    }
    
    private func shareUrlAction(currentUrl: URL) {
        guard case .webPage = context.style else {
            return
        }
        
        let vc = MessageReceiverViewController.instance(content: .text(currentUrl.absoluteString))
        navigationController?.pushViewController(vc, animated: true)
    }
    
}

extension MixinWebViewController {
    
    enum Script {
        static let getThemeColor = """
            function getColor() {
                const metas = document.getElementsByTagName('meta');
                for (var i = metas.length - 1; i >= 0; i--) {
                    if (metas[i].getAttribute('name') === 'theme-color' && metas[i].hasAttribute('content')) {
                        return metas[i].getAttribute('content');
                    }
                }
                return '';
            }
            getColor();
        """
        static let disableImageSelection: WKUserScript = {
            let string = """
                var style = document.createElement('style');
                style.innerHTML = 'img { -webkit-user-select: none; -webkit-touch-callout: none; }';
                document.head.appendChild(style)
            """
            return WKUserScript(source: string,
                                injectionTime: .atDocumentEnd,
                                forMainFrameOnly: true)
        }()
    }
    
    struct Context {
        
        enum Style {
            case webPage
            case app(appId: String, title: String, iconUrl: URL?)
        }
        
        let conversationId: String
        let style: Style
        let initialUrl: URL
        let isImmersive: Bool
        
        var appContextString: String {
            let appearance: String = {
                if #available(iOS 13.0, *), UITraitCollection.current.userInterfaceStyle == .dark {
                    return "dark"
                } else {
                    return "light"
                }
            }()
            let ctx: [String: Any] = [
                "app_version": Bundle.main.shortVersion,
                "immersive": isImmersive,
                "appearance": appearance,
                "conversation_id": conversationId
            ]
            if let data = try? JSONSerialization.data(withJSONObject: ctx, options: []), let string = String(data: data, encoding: .utf8) {
                return string
            } else {
                return ""
            }
        }
        
        init(conversationId: String, app: App) {
            self.conversationId = conversationId
            style = .app(appId: app.appId, title: app.name, iconUrl: URL(string: app.iconUrl))
            initialUrl = URL(string: app.homeUri) ?? .blank
            isImmersive = app.capabilities?.contains("IMMERSIVE") ?? false
        }
        
        init(conversationId: String, initialUrl: URL) {
            self.conversationId = conversationId
            style = .webPage
            self.initialUrl = initialUrl
            isImmersive = false
        }
        
        init(conversationId: String, url: URL, app: App) {
            self.conversationId = conversationId
            style = .app(appId: app.appId, title: app.name, iconUrl: URL(string: app.iconUrl))
            initialUrl = url
            isImmersive = app.capabilities?.contains("IMMERSIVE") ?? false
        }
        
    }
    
}
