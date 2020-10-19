import UIKit
import WebKit
import Alamofire
import MixinServices

class MixinWebViewController: WebViewController {
    
    private enum HandlerName {
        static let mixinContext = "MixinContext"
        static let reloadTheme = "reloadTheme"
    }
    
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
        config.applicationNameForUserAgent = "Mixin/\(Bundle.main.shortVersion)"
        return config
    }
    
    private let loadingIndicator = AppLoadingIndicatorView(frame: .zero)
    
    private(set) var context: Context!
    
    private var webViewTitleObserver: NSKeyValueObservation?
    
    class func instance(with context: Context) -> MixinWebViewController {
        let vc = MixinWebViewController(nib: R.nib.webView)
        vc.context = context
        return vc
    }
    
    class func presentInstance(with context: Context, asChildOf parent: UIViewController) {
        let vc = Self.instance(with: context)
        vc.presentAsChild(of: parent, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        contentView.insertSubview(loadingIndicator, belowSubview: suspicionView)
        loadingIndicator.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
        }
        loadingIndicator.startAnimating()
        showPageTitleConstraint.priority = context.isImmersive ? .defaultLow : .defaultHigh
        webView.navigationDelegate = self
        webView.uiDelegate = self
        loadWebView()
    }
    
    func presentAsChild(of parent: UIViewController, completion: (() -> Void)?) {
        view.frame = parent.view.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        parent.addChild(self)
        let parentView: UIView
        if let view = parent.view as? UIVisualEffectView {
            parentView = view.contentView
        } else {
            parentView = parent.view
        }
        parentView.addSubview(view)
        didMove(toParent: parent)
        
        view.center.y = parent.view.bounds.height * 3 / 2
        UIView.animate(withDuration: 0.5) {
            UIView.setAnimationCurve(.overdamped)
            self.view.center.y = parent.view.bounds.height / 2
        } completion: { (_) in
            completion?()
        }
        
        AppDelegate.current.mainWindow.endEditing(true)
    }
    
    private func loadNormalUrl() {
        webViewTitleObserver = webView.observe(\.title, options: [.initial, .new], changeHandler: { [weak self] (webView, _) in
            guard let weakSelf = self, case .webPage = weakSelf.context.style else {
                return
            }
            self?.titleLabel.text = webView.title
        })
        webView.load(URLRequest(url: context.initialUrl))
    }

    private func loadAppUrl(title: String, iconUrl: URL?) {
        titleLabel.text = title
        if let iconUrl = iconUrl {
            titleImageView.isHidden = false
            titleImageView.sd_setImage(with: iconUrl, completed: nil)
        }
        webView.load(URLRequest(url: context.initialUrl))
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: HandlerName.mixinContext)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: HandlerName.reloadTheme)
    }

    override func continueAction(_ sender: Any) {
        suspicionView.isHidden = true
        loadNormalUrl()
    }

    override func reloadAction(_ sender: Any) {
        reloadWebView()
    }

    private func reloadWebView() {
        loadFailView.isHidden = true
        if let currentUrl = webView.url {
            let request = URLRequest(url: currentUrl,
                                     cachePolicy: .reloadIgnoringLocalCacheData,
                                     timeoutInterval: 10)
            self.webView.load(request)
        } else {
            loadWebView()
        }
    }

    private func loadWebView() {
        switch context.style {
        case .webPage:
            loadNormalUrl()
        case let .app(app, isHomeUrl):
            let appId = app.appId
            let title = app.name
            let iconUrl = URL(string: app.iconUrl)
            if isHomeUrl {
                loadAppUrl(title: title, iconUrl: iconUrl)
            } else {
                let validUrl = context.initialUrl.absoluteString + "/"
                DispatchQueue.global().async { [weak self] in
                    var app = AppDAO.shared.getApp(appId: appId)
                    if app == nil || !(app?.resourcePatterns?.contains(where: validUrl.hasPrefix) ?? false) {
                        if case let .success(response) = UserAPI.showUser(userId: appId) {
                            UserDAO.shared.updateUsers(users: [response])
                            app = response.app
                        }
                    }

                    DispatchQueue.main.async {
                        guard let weakSelf = self else {
                            return
                        }
                        if app?.resourcePatterns?.contains(where: validUrl.hasPrefix) ?? false {
                            weakSelf.loadAppUrl(title: title, iconUrl: iconUrl)
                        } else {
                            weakSelf.suspicionView.isHidden = false
                            weakSelf.context.style = .webPage
                            weakSelf.context.isImmersive = false
                        }
                    }
                }
            }
        }
    }

    override func contactDeveloperAction(_ sender: Any) {
        guard case let .app(app, _) = context.style else {
            return
        }

        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        DispatchQueue.global().async { [weak self] in
            guard let developerUserId = Self.syncUser(userId: app.appId, hud: hud)?.appCreatorId else {
                return
            }
            guard let developUser = Self.syncUser(userId: developerUserId, hud: hud) else {
               return
            }
            DispatchQueue.main.async {
                hud.hide()
                UIApplication.homeNavigationController?.pushViewController(withBackRoot: ConversationViewController.instance(ownerUser: developUser))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    self?.dismiss()
                }
            }
        }
    }

    private static func syncUser(userId: String, hud: Hud) -> UserItem? {
        if let user = UserDAO.shared.getUser(userId: userId) {
            return user
        } else {
            switch UserAPI.showUser(userId: userId) {
            case let .success(userItem):
                let user = UserItem.createUser(from: userItem)
                UserDAO.shared.updateUsers(users: [userItem])
                return user
            case let .failure(error):
                DispatchQueue.main.async {
                    let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.user_not_found())
                    hud.set(style: .error, text: text)
                    hud.scheduleAutoHidden()
                }
                return nil
            }
        }
    }
    
    override func moreAction(_ sender: Any) {
        let floatAction: WebMoreMenuViewController.MenuItem
        if UIApplication.clipSwitcher.clips.contains(where: { $0.controller == self }) {
            floatAction = .cancelFloat
        } else {
            floatAction = .float
        }
        let sections: [[WebMoreMenuViewController.MenuItem]]
        switch context.style {
        case .app:
            sections = [[.share], [floatAction], [.about, .refresh]]
        case .webPage:
            sections = [[.share], [floatAction], [.copyLink, .refresh, .openInSafari]]
        }
        let more = WebMoreMenuViewController(sections: sections)
        more.overrideStatusBarStyle = preferredStatusBarStyle
        more.titleView.titleLabel.text = titleLabel.text
        switch context.style {
        case let .app(app, _):
            more.titleView.subtitleLabel.text = app.appNumber
            more.titleView.imageView.isHidden = false
            more.titleView.imageView.setImage(app: app)
        case .webPage:
            more.titleView.subtitleLabel.text = (context.initialUrl.host ?? "") + context.initialUrl.path
            more.titleView.imageView.isHidden = true
        }
        more.delegate = self
        present(more, animated: true, completion: nil)
    }
    
}

extension MixinWebViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if UrlWindow.checkUrl(url: url, webContext: context) || UrlWindow.checkPayUrl(url: url.absoluteString) {
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

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        guard let failURL = nsError.userInfo["NSErrorFailingURLKey"] as? URL, let host = failURL.host else {
            return
        }
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut, NSURLErrorInternationalRoamingOff, NSURLErrorDataNotAllowed, NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost:
            loadFailView.isHidden = false
            loadFailLabel.text = R.string.localizable.web_cannot_reached_desc(host)
            if case .app = context.style {
                contactDeveloperButton.isHidden = false
            } else {
                contactDeveloperButton.isHidden = true
            }
        default:
            break
        }
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

extension MixinWebViewController: WebMoreMenuControllerDelegate {
    
    func webMoreMenuViewController(_ controller: WebMoreMenuViewController, didSelect item: WebMoreMenuViewController.MenuItem) {
        
        func handle() {
            let url = webView.url ?? .blank
            switch item {
            case .share:
                switch context.style {
                case .app:
                    shareAppCardAction(currentUrl: url)
                case .webPage:
                    shareUrlAction(currentUrl: url)
                }
            case .float:
                dismiss(completion: {
                    UIApplication.clipSwitcher.insert(self)
                })
            case .cancelFloat:
                if let index = UIApplication.clipSwitcher.clips.firstIndex(where: { $0.controller == self }) {
                    UIApplication.clipSwitcher.removeClip(at: index)
                }
            case .about:
                aboutAction()
            case .copyLink:
                copyAction(currentUrl: url)
            case .refresh:
                reloadWebView()
            case .openInSafari:
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        
        controller.dismiss(animated: true, completion: handle)
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
        guard case let .app(app, _) = context.style else {
            return
        }
        let appId = app.appId
        DispatchQueue.global().async {
            var userItem = UserDAO.shared.getUser(userId: appId)
            var updateUserFromRemoteAfterReloaded = true
            
            if userItem == nil, case let .success(response) = UserAPI.showUser(userId: appId) {
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

    private func shareAppCardAction(currentUrl: URL) {
        guard case let .app(app, _) = context.style else {
            return
        }
        let appId = app.appId
        var cardTitle = app.name
        if let webTitle = webView.title, !webTitle.trim().isEmpty {
            cardTitle = webTitle.trim()
        }

        DispatchQueue.global().async { [weak self] in
            var app = AppDAO.shared.getApp(appId: appId)
            if app == nil {
                if case let .success(response) = UserAPI.showUser(userId: appId) {
                    UserDAO.shared.updateUsers(users: [response])
                    app = response.app
                }
            }
            
            DispatchQueue.main.async {
                let validUrl = currentUrl.absoluteString + "/"
                if let app = app, let iconUrl = URL(string: app.iconUrl), app.resourcePatterns?.contains(where: validUrl.hasPrefix) ?? false {
                    let appCard = AppCardData(appId: app.appId, iconUrl: iconUrl, title: String(cardTitle.prefix(32)), description: String(app.name.prefix(64)), action: currentUrl, updatedAt: nil)
                    let vc = MessageReceiverViewController.instance(content: .appCard(appCard))
                    self?.navigationController?.pushViewController(vc, animated: true)
                } else {
                    let vc = MessageReceiverViewController.instance(content: .text(currentUrl.absoluteString))
                    self?.navigationController?.pushViewController(vc, animated: true)
                }
            }
        }
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
            case app(app: App, isHomeUrl: Bool)
        }
        
        let conversationId: String
        var style: Style
        let initialUrl: URL
        var isImmersive: Bool
        
        var appContextString: String {
            let ctx: [String: Any] = [
                "app_version": Bundle.main.shortVersion,
                "immersive": isImmersive,
                "appearance": UserInterfaceStyle.current.rawValue,
                "currency": Currency.current.code,
                "locale": "\(Locale.current.languageCode ?? "")-\(Locale.current.regionCode ?? "")",
                "platform": "iOS",
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
            style = .app(app: app, isHomeUrl: true)
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
            style = .app(app: app, isHomeUrl: false)
            initialUrl = url
            isImmersive = app.capabilities?.contains("IMMERSIVE") ?? false
        }
        
    }
    
}
