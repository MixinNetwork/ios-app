import UIKit
import WebKit
import Alamofire
import MixinServices

final class MixinWebViewController: WebViewController {
    
    // Only top 2 levels of the domain are matched
    // Be careful when adding country specific SLDs into this list
    // e.g. "anything.co.uk" will be matched if "something.co.uk" is added
    // See `loadURL(url:fraudulentWarning:)` for details
    private static let fraudulentWarningDisabledDomains = [
        "mixin.one",
        "zeromesh.net",
        "mixin.zone",
        "kraken.fm",
        "mixin.space",
        "mixinwallet.com",
        "ocean.one",
        "mvm.app",
        "mixin.dev",
        "mixwallet.app",
    ]
    
    private enum HandlerName: String, CaseIterable {
        case mixinContext = "MixinContext"
        case reloadTheme = "reloadTheme"
        case playlist = "playlist"
        case close = "close"
        case getTIPAddress = "getTipAddress"
        case tipSign = "tipSign"
        case getAssets = "getAssets"
        case web3Bridge = "_mw_"
        case signBotSignature = "signBotSignature"
    }
    
    private enum FradulentWarningBehavior {
        case byWhitelist // See `fraudulentWarningDisabledHosts`
        case disabled
    }
    
    private enum AppSigningError: Error {
        case noSuchApp
        case unauthorizedResource
    }
    
    @IBOutlet weak var loadFailLabel: UILabel!
    @IBOutlet weak var contactDeveloperButton: UIButton!
    
    weak var associatedClip: Clip?
    
    override var webViewConfiguration: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = .all
        config.preferences = WKPreferences()
        config.preferences.minimumFontSize = 12
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .video
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.userContentController.addUserScript(Script.disableImageSelection)
        if let scripts = web3ProviderScripts {
            scripts.forEach(config.userContentController.addUserScript(_:))
        }
        for name in HandlerName.allCases.map(\.rawValue) {
            config.userContentController.add(scriptMessageProxy, name: name)
        }
        config.applicationNameForUserAgent = "Mixin/\(Bundle.main.shortVersionString)"
        return config
    }
    
    private let loadingIndicator = AppLoadingIndicatorView(frame: .zero)
    private let defaultEVMChain: Web3Chain = .ethereum
    
    private(set) var context: Context!
    
    private lazy var scriptMessageProxy = ScriptMessageProxy(target: self)
    private lazy var suspicousLinkView = R.nib.suspiciousLinkView(withOwner: self)!
    private lazy var loadingFailureView: UIView = {
        let view = R.nib.webLoadingFailureView(withOwner: self)!
        loadingFailureViewIfLoaded = view
        return view
    }()
    private lazy var clipSwitcher = UIApplication.homeContainerViewController?.clipSwitcher
    private lazy var web3Worker = Web3Worker(webView: webView,
                                             evmChain: defaultEVMChain,
                                             solanaChain: .solana)
    
    private weak var loadingFailureViewIfLoaded: UIView?
    
    private var isMessageHandlerAdded = true
    private var webViewTitleObserver: NSKeyValueObservation?
    private var hasSavedAsRecentSearch = false
    
    private var web3ProviderScripts: [WKUserScript]? {
        let evmConfig: Script.EVMConfig? = {
            guard let address = Web3AddressDAO.shared.currentSelectedWalletAddress(chainID: ChainID.ethereum)?.destination else {
                return nil
            }
            let chain = defaultEVMChain
            guard case let .evm(chainID) = chain.specification else {
                assertionFailure()
                return nil
            }
            return .init(address: address, chainID: chainID, rpcURL: chain.rpcServerURL)
        }()
        let solanaConfig: Script.SolanaConfig? = {
            if let address = Web3AddressDAO.shared.currentSelectedWalletAddress(chainID: ChainID.solana) {
                Script.SolanaConfig(address: address.destination)
            } else {
                nil
            }
        }()
        guard let web3Config = Script.web3Config(evm: evmConfig, solana: solanaConfig) else {
            return nil
        }
        return [Script.web3Provider, web3Config]
    }
    
    deinit {
        #if DEBUG
        print("\(self) deinited")
        #endif
    }
    
    class func instance(with context: Context) -> MixinWebViewController {
        let vc = MixinWebViewController(nib: R.nib.fullscreenPopupView)
        vc.context = context
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        contentView.insertSubview(loadingIndicator, aboveSubview: webContentView)
        loadingIndicator.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
        }
        loadingIndicator.startAnimating()
        showPageTitleConstraint.priority = context.isImmersive ? .defaultLow : .defaultHigh
        webView.navigationDelegate = self
        webView.uiDelegate = self
#if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
#endif
        loadWebView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !isMessageHandlerAdded {
            for name in HandlerName.allCases.map(\.rawValue) {
                webView.configuration.userContentController.add(scriptMessageProxy, name: name)
            }
            isMessageHandlerAdded = true
        }
    }
    
    override func popupDidDismissAsChild() {
        super.popupDidDismissAsChild()
        if associatedClip == nil {
            // Remove message handlers here because viewDidDisappear: is not getting called
            // everytime view is disappeared. Since MixinWebViewController is always being
            // added as a child view controller of some parent controller, when the user pop that
            // parent view controller immediately after he dismiss this one, viewDidDisappear:
            // is not getting called.
            removeAllMessageHandlers()
        }
    }
    
    override func moreAction(_ sender: Any) {
        let floatAction: WebMoreMenuViewController.MenuItem
        if associatedClip == nil {
            floatAction = .float
        } else {
            floatAction = .cancelFloat
        }
        let sections: [[WebMoreMenuViewController.MenuItem]]
        switch context.style {
        case let .app(app, _):
            sections = [[.share, floatAction, .refresh], [.about, .viewAuthorization(app.appId)]]
        case .webPage:
            sections = [[.share, floatAction, .refresh], [.scanQRCode, .copyLink, .openInBrowser]]
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
    
    @IBAction func continueAction(_ sender: Any) {
        suspicousLinkView.removeFromSuperview()
        loadNormalUrl()
    }
    
    @IBAction func reloadAction(_ sender: Any) {
        loadingFailureViewIfLoaded?.removeFromSuperview()
        if let currentUrl = webView.url {
            let request = URLRequest(url: currentUrl,
                                     cachePolicy: .reloadIgnoringLocalCacheData,
                                     timeoutInterval: 10)
            self.webView.load(request)
        } else {
            loadWebView()
        }
    }
    
    @IBAction func contactDeveloperAction(_ sender: Any) {
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
                if let navigationController = self?.availableNavigationController {
                    let conversation = ConversationViewController.instance(ownerUser: developUser)
                    navigationController.pushViewController(withBackRoot: conversation)
                }
            }
        }
    }
    
    func removeAllMessageHandlers() {
        guard isViewLoaded && isMessageHandlerAdded else {
            return
        }
        let controller = webView.configuration.userContentController
        HandlerName.allCases.map(\.rawValue)
            .forEach(controller.removeScriptMessageHandler(forName:))
        isMessageHandlerAdded = false
    }
    
    func minimizeWithAnimation(completion: (() -> Void)? = nil) {
        guard
            let switcher = clipSwitcher, !switcher.isMaximumLimitReached,
            let controller = UIApplication.homeContainerViewController?.minimizedClipSwitcherViewController
        else {
            completion?()
            return
        }
        isBeingDismissedAsChild = true
        CATransaction.begin()
        let fromPath = UIBezierPath(roundedRect: view.bounds, cornerRadius: contentViewCornerRadius)
        let dx = controller.horizontalContentMargin / 2
        let dy = controller.verticalContentMargin / 2
        let toRect = controller.view.frame.insetBy(dx: dx, dy: dy)
        let toPath = UIBezierPath(roundedRect: toRect, cornerRadius: toRect.size.height / 2)
        let basicAniamtion = CABasicAnimation(keyPath: "path")
        basicAniamtion.duration = 0.3
        basicAniamtion.fromValue = fromPath.cgPath
        basicAniamtion.toValue = toPath.cgPath
        basicAniamtion.timingFunction = CAMediaTimingFunction(name: .easeIn)
        let maskLayer = CAShapeLayer()
        maskLayer.path = toPath.cgPath
        view.layer.mask = maskLayer
        CATransaction.setCompletionBlock {
            self.willMove(toParent: nil)
            self.view.layer.mask = nil
            self.view.removeFromSuperview()
            self.removeFromParent()
            self.clipSwitcher?.appendClip(with: self)
            completion?()
            self.isBeingDismissedAsChild = false
            self.popupDidDismissAsChild()
        }
        maskLayer.add(basicAniamtion, forKey: "pathAnimation")
        CATransaction.commit()
    }
    
}

extension MixinWebViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if isViewLoaded && parent != nil && (UrlWindow.checkUrl(url: url, from: .webView(context)) || UrlWindow.checkWithdrawal(string: url.absoluteString)) {
            decisionHandler(.cancel)
        } else if "file" == url.scheme {
            decisionHandler(.allow)
        } else if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
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
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard !loadingIndicator.isHidden else {
            return
        }
        loadingIndicator.stopAnimating()
        loadingIndicator.isHidden = true
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.isOpaque = true
        reloadTheme(webView: webView)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        guard let failURL = nsError.userInfo["NSErrorFailingURLKey"] as? URL, let host = failURL.host else {
            return
        }
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut, NSURLErrorInternationalRoamingOff, NSURLErrorDataNotAllowed, NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost:
            if loadingFailureView.superview == nil {
                contentView.insertSubview(loadingFailureView, belowSubview: pageControlView)
                loadingFailureView.snp.makeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    make.top.bottom.equalTo(contentView.safeAreaLayoutGuide)
                }
            }
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
        if prompt == HandlerName.mixinContext.rawValue + ".getContext()" {
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
        guard let handlerName = HandlerName(rawValue: message.name) else {
            return
        }
        switch handlerName {
        case .mixinContext:
            break
        case .reloadTheme:
            reloadTheme(webView: webView)
        case .playlist:
            if let body = message.body as? [String] {
                let playlist = body.compactMap(PlaylistItem.init)
                if !playlist.isEmpty {
                    PlaylistManager.shared.play(index: 0, in: playlist, source: .remote)
                }
            }
        case .close:
            dismissAsChild(animated: true, completion: nil)
        case .getTIPAddress:
            if let body = message.body as? [String], body.count == 2 {
                // let chainId = body[0]
                let callback = body[1]
                let address = "" // Empty address as rejection
                webView.evaluateJavaScript("\(callback)('\(address)');")
            }
        case .tipSign:
            if let body = message.body as? [String], body.count == 3 {
                // let chainId = body[0]
                // let message = body[1]
                let callback = body[2]
                let signature = "" // Empty signature as rejection
                webView.evaluateJavaScript("\(callback)('\(signature)');")
            }
        case .getAssets:
            if let body = message.body as? [Any],
               body.count == 2,
               let assetIDs = body[0] as? [String],
               let callback = body[1] as? String
            {
                reportAssets(ids: assetIDs, callback: callback)
            }
        case .web3Bridge:
            let body: [String: Any]
            if let string = message.body as? String,
               let data = string.data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: data, options: []),
               let dict = object as? [String: Any]
            {
                body = dict
            } else if let object = message.body as? [String: Any] {
                body = object
            } else {
                return
            }
            web3Worker.handleRequest(json: body)
        case .signBotSignature:
            guard
                let url = webView.url,
                let messageBody = message.body as? [Any],
                messageBody.count >= 6,
                let appID = messageBody[0] as? String,
                let reloadPublicKey = messageBody[1] as? Bool,
                let method = messageBody[2] as? String,
                let path = messageBody[3] as? String,
                let body = messageBody[4] as? String,
                let callback = messageBody[5] as? String
            else {
                return
            }
            DispatchQueue.global().async { [weak webView] in
                do {
                    let app: App?
                    if let localApp = AppDAO.shared.getApp(appId: appID) {
                        app = localApp
                    } else {
                        switch UserAPI.showUser(userId: appID) {
                        case .success(let response):
                            UserDAO.shared.updateUsers(users: [response])
                            app = response.app
                        case .failure:
                            app = nil
                        }
                    }
                    guard let app else {
                        throw AppSigningError.noSuchApp
                    }
                    guard app.resourcePatterns(accepts: url) else {
                        throw AppSigningError.unauthorizedResource
                    }
                    let signature = try RouteAPI.sign(
                        appID: appID,
                        reloadPublicKey: reloadPublicKey,
                        method: method,
                        path: path,
                        body: body.data(using: .utf8)
                    )
                    DispatchQueue.main.async {
                        webView?.evaluateJavaScript("\(callback)('\(signature.timestamp)', '\(signature.signature)');")
                    }
                } catch {
                    DispatchQueue.main.async {
                        webView?.evaluateJavaScript("\(callback)(null);")
                    }
                }
            }
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
                    if context.isShareable ?? true {
                        shareAppCardAction(currentUrl: url)
                    } else {
                        presentGotItAlertController(title: R.string.localizable.link_shareable_false())
                    }
                case .webPage:
                    shareUrlAction(currentUrl: url)
                }
            case .float:
                if let switcher = clipSwitcher {
                    if switcher.isMaximumLimitReached {
                        let text = R.string.localizable.floats_allows_up_to_count(ClipSwitcher.maxNumber)
                        showAutoHiddenHud(style: .error, text: text)
                    } else {
                        minimizeWithAnimation()
                    }
                }
            case .cancelFloat:
                if let clip = associatedClip,
                   let switcher = clipSwitcher,
                   let index = switcher.clips.firstIndex(of: clip) {
                    switcher.removeClip(at: index)
                }
                associatedClip = nil
            case .about:
                aboutAction()
            case .scanQRCode:
                scanQRCodeOnCurrentPage()
            case .copyLink:
                copyAction(currentUrl: url)
            case .refresh:
                reloadAction(controller)
            case .openInBrowser:
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            case .viewAuthorization(let appId):
                let vc = PermissionsViewController.instance(dataSource: .app(id: appId))
                availableNavigationController?.pushViewController(vc, animated: true)
            }
        }
        
        controller.dismiss(animated: true, completion: handle)
    }
    
}

extension MixinWebViewController {
    
    private func saveAsRecentSearchIfNeeded() {
        guard !hasSavedAsRecentSearch && context.saveAsRecentSearch else {
            return
        }
        guard var title = webView.title, !title.isEmpty else {
            return
        }
        if title.count > 50 {
            title = title.prefix(49) + "…"
        }
        let item: RecentSearch = .link(title: title, url: context.initialUrl)
        AppGroupUserDefaults.User.insertRecentSearch(item)
        hasSavedAsRecentSearch = true
    }
    
    private func loadNormalUrl() {
        webViewTitleObserver = webView.observe(\.title, options: [.initial, .new], changeHandler: { [weak self] (webView, _) in
            guard let self, case .webPage = self.context.style else {
                return
            }
            self.titleLabel.text = webView.title
            self.saveAsRecentSearchIfNeeded()
        })
        loadURL(url: context.initialUrl, fraudulentWarning: .byWhitelist)
    }

    private func loadAppUrl(title: String, iconUrl: URL?, appID: String) {
        titleLabel.text = title
        if let iconUrl = iconUrl {
            titleImageView.isHidden = false
            titleImageView.sd_setImage(with: iconUrl, completed: nil)
        }
        let url: URL
        if !context.extraParams.isEmpty, var components = URLComponents(url: context.initialUrl, resolvingAgainstBaseURL: true) {
            var queryItems: [URLQueryItem] = components.queryItems ?? []
            for item in context.extraParams {
                queryItems.append(URLQueryItem(name: item.key, value: item.value))
            }
            components.queryItems = queryItems
            url = components.url ?? context.initialUrl
        } else {
            url = context.initialUrl
        }
        DispatchQueue.global().async {
            let isVerified = UserDAO.shared.isUserVerified(withAppID: appID)
            DispatchQueue.main.async {
                self.loadURL(url: url, fraudulentWarning: isVerified ? .disabled : .byWhitelist)
            }
        }
    }
    
    private func loadURL(url: URL, fraudulentWarning: FradulentWarningBehavior) {
        let enabled: Bool
        switch fraudulentWarning {
        case .byWhitelist:
            if let host = url.host {
                let domainComponents = host.components(separatedBy: ".")
                if domainComponents.count < 2 {
                    enabled = true
                } else {
                    let topLevelDomain = domainComponents[domainComponents.count - 1]
                    let secondLevelDomain = domainComponents[domainComponents.count - 2]
                    let domainSuffix = secondLevelDomain + "." + topLevelDomain
                    enabled = !Self.fraudulentWarningDisabledDomains.contains(domainSuffix)
                }
            } else {
                enabled = true
            }
        case .disabled:
            enabled = false
        }
        webView.configuration.preferences.isFraudulentWebsiteWarningEnabled = enabled
        webView.load(URLRequest(url: url))
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
                loadAppUrl(title: title, iconUrl: iconUrl, appID: appId)
            } else {
                let initialURL = context.initialUrl
                DispatchQueue.global().async { [weak self] in
                    var app = AppDAO.shared.getApp(appId: appId)
                    if app == nil || !(app?.resourcePatterns(accepts: initialURL) ?? false) {
                        if case let .success(response) = UserAPI.showUser(userId: appId) {
                            UserDAO.shared.updateUsers(users: [response])
                            app = response.app
                        }
                    }
                    DispatchQueue.main.async {
                        guard let self = self else {
                            return
                        }
                        if app?.resourcePatterns(accepts: initialURL) ?? false {
                            self.loadAppUrl(title: title, iconUrl: iconUrl, appID: appId)
                        } else {
                            if self.suspicousLinkView.superview == nil {
                                self.contentView.insertSubview(self.suspicousLinkView,
                                                               belowSubview: self.pageControlView)
                                self.suspicousLinkView.snp.makeConstraints { make in
                                    make.leading.trailing.equalToSuperview()
                                    make.top.bottom.equalTo(self.contentView.safeAreaLayoutGuide)
                                }
                            }
                            self.context.style = .webPage
                            self.context.isImmersive = false
                        }
                    }
                }
            }
        }
    }
    
    private func reloadTheme(webView: WKWebView) {
        webView.evaluateJavaScript(Script.getThemeColor) { [weak self] (result, error) in
            guard let colorString = result as? String else {
                return
            }
            let color = UIColor(hexString: colorString) ?? .background
            self?.updateBackground(pageThemeColor: color, measureDarknessWithUserInterfaceStyle: false)
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
    
    private func scanQRCodeOnCurrentPage() {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        let config = WKSnapshotConfiguration()
        config.rect = webView.frame
        config.snapshotWidth = NSNumber(value: Int(webView.frame.width))
        webView.takeSnapshot(with: config) { image, error in
            if let image, let cgImage = image.cgImage, let detector = qrCodeDetector {
                let ciImage = CIImage(cgImage: cgImage)
                for case let feature as CIQRCodeFeature in detector.features(in: ciImage) {
                    guard let string = feature.messageString else {
                        continue
                    }
                    hud.hide()
                    UrlWindow.checkQrCodeDetection(string: string, clearNavigationStack: false)
                    return
                }
                hud.set(style: .warning, text: R.string.localizable.qr_code_not_found())
                hud.scheduleAutoHidden()
            } else if let error {
                hud.set(style: .error, text: error.localizedDescription)
                hud.scheduleAutoHidden()
            } else {
                hud.set(style: .error, text: R.string.localizable.qr_code_not_found())
                hud.scheduleAutoHidden()
            }
        }
    }
    
    private func copyAction(currentUrl: URL) {
        UIPasteboard.general.string = currentUrl.absoluteString
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }

    private func shareAppCardAction(currentUrl: URL) {
        guard case let .app(app, _) = context.style else {
            return
        }
        let appId = app.appId
        let isShareable = context.isShareable
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
                guard let navigationController = self?.availableNavigationController else {
                    return
                }
                if let app = app,
                   let iconUrl = URL(string: app.iconUrl),
                   app.resourcePatterns(accepts: currentUrl)
                {
                    let content = AppCardData.V0Content(appId: app.appId,
                                                        iconUrl: iconUrl,
                                                        title: String(cardTitle.prefix(32)),
                                                        description: String(app.name.prefix(64)),
                                                        action: currentUrl,
                                                        updatedAt: nil,
                                                        isShareable: isShareable)
                    let vc = MessageReceiverViewController.instance(content: .appCard(.v0(content)))
                    navigationController.pushViewController(vc, animated: true)
                } else {
                    let vc = MessageReceiverViewController.instance(content: .text(currentUrl.absoluteString))
                    navigationController.pushViewController(vc, animated: true)
                }
            }
        }
    }

    private func shareUrlAction(currentUrl: URL) {
        guard case .webPage = context.style else {
            return
        }
        let vc = MessageReceiverViewController.instance(content: .text(currentUrl.absoluteString))
        availableNavigationController?.pushViewController(vc, animated: true)
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
    
    private func reportAssets(ids assetIDs: [String], callback: String) {
        let failureCallback = "\(callback)('[]');"
        guard assetIDs.allSatisfy(UUID.isValidLowercasedUUIDString) else {
            webView.evaluateJavaScript(failureCallback)
            return
        }
        switch context.style {
        case let .app(app, _):
            guard let appHomeURL = URL(string: app.homeUri), let currentURL = webView.url, appHomeURL.host == currentURL.host else {
                webView.evaluateJavaScript(failureCallback)
                return
            }
            AuthorizeAPI.authorizations(appId: app.appId) { [weak webView] result in
                switch result {
                case let .success(response):
                    guard let scopes = response.first?.scopes, scopes.contains("ASSETS:READ") else {
                        webView?.evaluateJavaScript(failureCallback)
                        return
                    }
                    DispatchQueue.global().async {
                        let tokens = TokenDAO.shared.appTokens(ids: assetIDs)
                        if let data = try? JSONEncoder.default.encode(tokens), let string = String(data: data, encoding: .utf8) {
                            let assets = string.replacingOccurrences(of: "'", with: "\\'")
                            DispatchQueue.main.async {
                                webView?.evaluateJavaScript("\(callback)('\(assets)');")
                            }
                        } else {
                            DispatchQueue.main.async {
                                webView?.evaluateJavaScript(failureCallback)
                            }
                        }
                    }
                case .failure:
                    webView?.evaluateJavaScript(failureCallback)
                }
            }
        case .webPage:
            webView.evaluateJavaScript(failureCallback)
        }
    }
    
}

extension MixinWebViewController {
    
    private enum Script {
        
        struct EVMConfig {
            let address: String
            let chainID: Int
            let rpcURL: URL
        }
        
        struct SolanaConfig {
            let address: String
        }
        
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
        
        static let web3Provider: WKUserScript = {
            let source = try! String(contentsOf: R.file.mixinMinJs()!)
            return WKUserScript(source: source,
                                injectionTime: .atDocumentStart,
                                forMainFrameOnly: false)
        }()
        
        static func web3Config(evm: EVMConfig?, solana: SolanaConfig?) -> WKUserScript? {
            guard evm != nil || solana != nil else {
                return nil
            }
            var configs = ""
            if let evm {
                configs.append("""
                    ethereum: {
                        address: "\(evm.address)",
                        chainId: \(evm.chainID),
                        rpcUrl: "\(evm.rpcURL.absoluteString)"
                    },
                """)
            }
            if let solana {
                configs.append("""
                    solana: {
                        cluster: "mainnet-beta",
                        address: "\(solana.address)",
                    },
                """)
            }
            let source = """
                (function() {
                    var config = {
                        \(configs)
                        isDebug: false
                    };
                    if (config.ethereum) {
                        mixinwallet.ethereum = new mixinwallet.Provider(config);
                        window.ethereum = mixinwallet.ethereum;
                        window.ethereum.setAddress(config.ethereum.address);
                    }
                    if (config.solana) {
                        mixinwallet.solana = new mixinwallet.SolanaProvider(config);
                        window.solana = mixinwallet.solana;
                        window.solana.setAddress(config.solana.address);
                    }
                    mixinwallet.postMessage = (jsonString) => {
                        webkit.messageHandlers._mw_.postMessage(jsonString)
                    };
                    
                    const mixinLogoDataUrl = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNTEyIiBoZWlnaHQ9IjUxMiIgdmlld0JveD0iMCAwIDUxMiA1MTIiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxwYXRoIGQ9Ik0wIDExMkMwIDUwLjE0NDEgNTAuMTQ0MSAwIDExMiAwSDQwMEM0NjEuODU2IDAgNTEyIDUwLjE0NDEgNTEyIDExMlY0MDBDNTEyIDQ2MS44NTYgNDYxLjg1NiA1MTIgNDAwIDUxMkgxMTJDNTAuMTQ0MSA1MTIgMCA0NjEuODU2IDAgNDAwVjExMloiIGZpbGw9InVybCgjcGFpbnQwX2xpbmVhcl8yNzk1XzE3KSIvPgo8cGF0aCBmaWxsLXJ1bGU9ImV2ZW5vZGQiIGNsaXAtcnVsZT0iZXZlbm9kZCIgZD0iTTM4MS43NDkgMTU2QzM4My43NTggMTU2IDM4NS4zOTMgMTU3LjU5OCAzODUuNDU0IDE1OS41OTJMMzg1LjQ1NiAxNTkuNzA3VjM1MS4yOTJDMzg1LjQ1NiAzNTEuODQyIDM4NS4zMzMgMzUyLjM4NiAzODUuMDk3IDM1Mi44ODNDMzg0LjIzNiAzNTQuNjk2IDM4Mi4wOTQgMzU1LjQ4OCAzODAuMjY4IDM1NC42OUwzODAuMTU4IDM1NC42NEwzMzIuNjM0IDMzMi4wNTZDMzMwLjQyIDMzMS4wMDMgMzI4Ljk5MiAzMjguNzk1IDMyOC45MzMgMzI2LjM1M0wzMjguOTMxIDMyNi4xOTZWMTgxLjUzOEMzMjguOTMxIDE3OC45NDkgMzMwLjQ3IDE3Ni42MTMgMzMyLjgzNiAxNzUuNTg3TDMzMi45NzYgMTc1LjUyOEwzODAuMzU0IDE1Ni4yNzNDMzgwLjc5NyAxNTYuMDkzIDM4MS4yNzEgMTU2IDM4MS43NDkgMTU2Wk0xMjkuNzA3IDE1NkMxMzAuMTg1IDE1NiAxMzAuNjU5IDE1Ni4wOTMgMTMxLjEwMiAxNTYuMjczTDE3OC40OCAxNzUuNTI4QzE4MC45MjUgMTc2LjUyMiAxODIuNTI0IDE3OC44OTggMTgyLjUyNCAxODEuNTM4VjMyNi4xOTZDMTgyLjUyNCAzMjguNyAxODEuMDgzIDMzMC45ODEgMTc4LjgyMiAzMzIuMDU2TDEzMS4yOTcgMzU0LjY0QzEyOS40NDggMzU1LjUxOSAxMjcuMjM3IDM1NC43MzIgMTI2LjM1OSAzNTIuODgzQzEyNi4xMjMgMzUyLjM4NiAxMjYgMzUxLjg0MiAxMjYgMzUxLjI5MlYxNTkuNzA3QzEyNiAxNTcuNjYgMTI3LjY1OSAxNTYgMTI5LjcwNyAxNTZaTTI1OS44OTggMTk3Ljg0N0wzMDMuNzE5IDIyMy4xNTFDMzA2LjMgMjI0LjY0MSAzMDcuODg5IDIyNy4zOTUgMzA3Ljg4OSAyMzAuMzc1VjI4MC45ODJDMzA3Ljg4OSAyODMuOTYyIDMwNi4zIDI4Ni43MTYgMzAzLjcxOSAyODguMjA2TDI1OS44OTggMzEzLjUxQzI1Ny4zMTcgMzE0Ljk5OSAyNTQuMTM4IDMxNC45OTkgMjUxLjU1OCAzMTMuNTFMMjA3LjczNiAyODguMjA2QzIwNS4xNTYgMjg2LjcxNiAyMDMuNTY2IDI4My45NjIgMjAzLjU2NiAyODAuOTgyVjIzMC4zNzVDMjAzLjU2NiAyMjcuMzk1IDIwNS4xNTYgMjI0LjY0MSAyMDcuNzM2IDIyMy4xNTFMMjUxLjU1OCAxOTcuODQ3QzI1NC4xMzggMTk2LjM1NyAyNTcuMzE3IDE5Ni4zNTcgMjU5Ljg5OCAxOTcuODQ3WiIgZmlsbD0id2hpdGUiLz4KPGRlZnM+CjxsaW5lYXJHcmFkaWVudCBpZD0icGFpbnQwX2xpbmVhcl8yNzk1XzE3IiB4MT0iMTMuNSIgeTE9IjUxMiIgeDI9IjUxMiIgeTI9Ii0xLjYxODczZS0wNSIgZ3JhZGllbnRVbml0cz0idXNlclNwYWNlT25Vc2UiPgo8c3RvcCBzdG9wLWNvbG9yPSIjMkE1QkY2Ii8+CjxzdG9wIG9mZnNldD0iMSIgc3RvcC1jb2xvcj0iIzUyOUZGOSIvPgo8L2xpbmVhckdyYWRpZW50Pgo8L2RlZnM+Cjwvc3ZnPgo=';
                    const info = {
                        uuid: crypto.randomUUID(),
                        name: 'Mixin Messenger',
                        icon: mixinLogoDataUrl,
                        rdns: 'one.mixin.messenger',
                    };

                    function initializeEIP6963(provider, options = {}) {
                        const providerDetail = {
                            info,
                            provider
                        };
                        Object.defineProperty(providerDetail, 'provider', {
                            get() {
                                options.onAccessProvider?.();
                                return provider;
                            },
                        });
                        const announceEvent = new CustomEvent('eip6963:announceProvider', {
                            detail: Object.freeze(providerDetail),
                        });
                        window.dispatchEvent(announceEvent);

                        window.addEventListener('eip6963:requestProvider', () => {
                            window.dispatchEvent(announceEvent);
                            options.onRequestProvider?.();
                        });
                    }
                    initializeEIP6963(window.ethereum);
                })();
            """
            return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        }
        
    }
    
    struct Context {
        
        enum Style {
            case webPage
            case app(app: App, isHomeUrl: Bool)
        }
        
        let conversationId: String
        let initialUrl: URL
        let isShareable: Bool?
        let saveAsRecentSearch: Bool
        
        var style: Style
        var isImmersive: Bool
        var extraParams: [String: String] = [:]
        
        var appContextString: String {
            let ctx: [String: Any] = [
                "app_version": Bundle.main.shortVersionString,
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
        
        init(conversationId: String, app: App, shareable: Bool? = nil, extraParams: [String: String] = [:]) {
            if conversationId.isEmpty {
                self.conversationId = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: app.appId)
            } else {
                self.conversationId = conversationId
            }
            self.initialUrl = URL(string: app.homeUri) ?? .blank
            self.isShareable = shareable
            self.saveAsRecentSearch = false
            self.style = .app(app: app, isHomeUrl: true)
            self.isImmersive = app.capabilities?.contains("IMMERSIVE") ?? false
            self.extraParams = extraParams
        }
        
        init(conversationId: String, initialUrl: URL, shareable: Bool? = nil, saveAsRecentSearch: Bool = false) {
            self.conversationId = conversationId
            self.initialUrl = initialUrl
            self.isShareable = shareable
            self.saveAsRecentSearch = saveAsRecentSearch
            self.style = .webPage
            self.isImmersive = false
        }
        
        init(conversationId: String, url: URL, app: App, shareable: Bool? = nil) {
            self.conversationId = conversationId
            self.initialUrl = url
            self.isShareable = shareable
            self.saveAsRecentSearch = false
            self.style = .app(app: app, isHomeUrl: false)
            self.isImmersive = app.capabilities?.contains("IMMERSIVE") ?? false
        }
        
    }
    
}
