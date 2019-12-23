import UIKit
import WebKit
import Photos
import Alamofire
import FirebaseMLCommon
import FirebaseMLVision
import MixinServices

class WebViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var statusBarBackgroundView: UIView!
    @IBOutlet weak var titleWrapperView: UIView!
    @IBOutlet weak var titleImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var webViewWrapperView: UIView!
    @IBOutlet weak var buttonsWrapperView: UIView!
    @IBOutlet weak var buttonsBackgroundView: UIView!
    @IBOutlet weak var buttonsBackgroundEffectView: UIVisualEffectView!
    @IBOutlet weak var buttonsSeparatorLineView: UIView!
    @IBOutlet weak var moreButton: UIButton!
    @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet weak var loadingIndicator: AppLoadingIndicatorView!
    @IBOutlet weak var edgePanGestureRecognizer: WebViewScreenEdgePanGestureRecognizer!
    
    @IBOutlet weak var showPageTitleConstraint: NSLayoutConstraint!
    
    private(set) var isBeingDismissedAsChild = false
    
    private let messageHandlerName = "MixinContext"
    private let reloadThemeHandlerName = "reloadTheme"
    
    private let buttonDarkColor = UIColor(displayP3RgbValue: 0x2E2F31)
    private let textDarkColor = UIColor(displayP3RgbValue: 0x333333)
    
    private lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = .all
        config.preferences = WKPreferences()
        config.preferences.minimumFontSize = 12
        config.preferences.javaScriptEnabled = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .video
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.userContentController.addUserScript(Script.disableImageSelection)
        config.userContentController.add(self, name: messageHandlerName)
        config.userContentController.add(self, name: reloadThemeHandlerName)
        let frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        return WKWebView(frame: frame, configuration: config)
    }()
    
    private var context: Context!
    private var statusBarStyle = UIStatusBarStyle.default
    private var webViewTitleObserver: NSKeyValueObservation?
    private var imageRequest: DataRequest?
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return statusBarStyle
    }
    
    class func presentInstance(with context: Context, asChildOf parent: UIViewController) {
        let vc = R.storyboard.common.web()!
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
    
    class func instance(context: Context) -> WebViewController {
        let vc = R.storyboard.common.web()!
        vc.context = context
        vc.modalPresentationStyle = .custom
        vc.modalPresentationCapturesStatusBarAppearance = true
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateBackground(pageThemeColor: .background)
        buttonsBackgroundView.layer.borderWidth = 1
        webViewWrapperView.addSubview(webView)
        webView.snp.makeEdgesEqualToSuperview()
        webView.isOpaque = false
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.panGestureRecognizer.require(toFail: edgePanGestureRecognizer)
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
        showPageTitleConstraint.priority = context.isImmersive ? .defaultLow : .defaultHigh
        let request = URLRequest(url: context.initialUrl)
        webView.load(request)
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        parent?.setNeedsStatusBarAppearanceUpdate()
        parent?.setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            self.parent?.setNeedsStatusBarAppearanceUpdate()
            self.parent?.setNeedsUpdateOfHomeIndicatorAutoHidden()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        imageRequest?.cancel()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: messageHandlerName)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: reloadThemeHandlerName)
    }
    
    @IBAction func moreAction(_ sender: Any) {
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

    private func aboutAction() {
        guard case let .app(appId, _, _) = context.style else {
            return
        }
        DispatchQueue.global().async {
            var userItem = UserDAO.shared.getUser(userId: appId)
            var updateUserFromRemoteAfterReloaded = true

            if userItem == nil {
                if case let .success(response) = UserAPI.shared.showUser(userId: appId) {
                    updateUserFromRemoteAfterReloaded = false
                    userItem = UserItem.createUser(from: response)
                    UserDAO.shared.updateUsers(users: [response])
                }
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
    
    @IBAction func dismissAction(_ sender: Any) {
        dismiss()
    }
    
    @IBAction func screenEdgePanAction(_ recognizer: WebViewScreenEdgePanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            if view.safeAreaInsets.top > 20 {
                contentView.layer.cornerRadius = 39
            } else {
                contentView.layer.cornerRadius = 20
            }
        case .changed:
            let scale = 1 - 0.2 * recognizer.fractionComplete
            contentView.transform = CGAffineTransform(scaleX: scale, y: scale)
        case .ended:
            dismiss()
        case .cancelled:
            UIView.animate(withDuration: 0.25, animations: {
                self.contentView.transform = .identity
            }, completion: { _ in
                self.contentView.layer.cornerRadius = 0
            })
        default:
            break
        }
    }
    
    @IBAction func extractImageAction(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else {
            return
        }
        imageRequest?.cancel()
        let location = round(recognizer.location(in: webView))
        let script = "document.elementFromPoint(\(location.x), \(location.y)).src"
        webView.evaluateJavaScript(script) { (urlString, error) in
            guard error == nil, let urlString = urlString as? String else {
                return
            }
            self.imageRequest = Alamofire.request(urlString).responseData(completionHandler: { [weak self] (response) in
                guard recognizer.state == .began || recognizer.state == .changed else {
                    return
                }
                guard case let .success(data) = response.result, let image = UIImage(data: data) else {
                    return
                }
                DispatchQueue.main.async {
                    self?.presentAlertController(for: image)
                }
            })
        }
    }
    
    func updateBackground(pageThemeColor: UIColor) {
        statusBarBackgroundView.backgroundColor = pageThemeColor
        titleWrapperView.backgroundColor = pageThemeColor
        webView.backgroundColor = pageThemeColor
        
        let themeColorIsDark = pageThemeColor.w3cLightness < 0.5
        buttonsBackgroundEffectView.effect = themeColorIsDark ? .darkBlur : .extraLightBlur
        titleLabel.textColor = themeColorIsDark ? .white : textDarkColor

        let tintColor: UIColor = themeColorIsDark ? .white : buttonDarkColor
        moreButton.tintColor = tintColor
        dismissButton.tintColor = tintColor
        
        let outlineColor: UIColor = themeColorIsDark
            ? UIColor.white.withAlphaComponent(0.1)
            : UIColor.black.withAlphaComponent(0.06)
        buttonsSeparatorLineView.backgroundColor = outlineColor
        buttonsBackgroundView.layer.borderColor = outlineColor.cgColor
        
        if #available(iOS 13.0, *) {
            statusBarStyle = themeColorIsDark ? .lightContent : .darkContent
        } else {
            statusBarStyle = themeColorIsDark ? .lightContent : .default
        }
        setNeedsStatusBarAppearanceUpdate()
    }
    
    private func dismiss() {
        if let parent = parent {
            isBeingDismissedAsChild = true
            parent.setNeedsStatusBarAppearanceUpdate()
            UIView.animate(withDuration: 0.5, animations: {
                UIView.setAnimationCurve(.overdamped)
                self.view.center.y = parent.view.bounds.height * 3 / 2
            }) { (_) in
                self.willMove(toParent: nil)
                self.view.removeFromSuperview()
                self.removeFromParent()
            }
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
    
    private func presentAlertController(for image: UIImage) {
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: Localized.CHAT_PHOTO_SAVE, style: .default, handler: { (_) in
            PHPhotoLibrary.checkAuthorization { (authorized) in
                if authorized {
                    PHPhotoLibrary.saveImageToLibrary(image: image)
                }
            }
        }))
        qrCodeDetector.detect(in: VisionImage(image: image), completion: { (features, error) in
            if error == nil, let string = features?.first?.rawValue {
                controller.addAction(UIAlertAction(title: Localized.SCAN_QR_CODE, style: .default, handler: { (_) in
                    if let url = URL(string: string), UrlWindow.checkUrl(url: url, clearNavigationStack: false) {
                        
                    } else {
                        RecognizeWindow.instance().presentWindow(text: string)
                    }
                }))
            }
            controller.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
            self.present(controller, animated: true, completion: nil)
        })
    }
    
}

extension WebViewController: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == reloadThemeHandlerName {
            reloadTheme(webView: webView)
        }
    }
    
}

extension WebViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Extract image recognizer
        return true
    }
    
}

extension WebViewController: WKNavigationDelegate {
    
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

extension WebViewController: WKUIDelegate {
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        if prompt == messageHandlerName + ".getContext()" {
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

extension WebViewController {
    
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
        
        private(set) lazy var appContextString: String = {
            let ctx: [String: Any] = [
                "app_version": Bundle.main.shortVersion,
                "immersive": isImmersive,
                "appearance": "light",
                "conversation_id": conversationId
            ]
            if let data = try? JSONSerialization.data(withJSONObject: ctx, options: []), let string = String(data: data, encoding: .utf8) {
                return string
            } else {
                return ""
            }
        }()
        
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

extension WebViewController {

    func reloadTheme(webView: WKWebView) {
        webView.evaluateJavaScript(Script.getThemeColor) { [weak self](result, error) in
            guard let colorString = result as? String else {
                return
            }
            let color = UIColor(hexString: colorString) ?? .background
            self?.updateBackground(pageThemeColor: color)
        }
    }

}
