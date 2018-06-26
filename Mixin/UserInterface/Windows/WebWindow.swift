import Foundation
import WebKit
import Photos

class WebWindow: ZoomWindow {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var webViewWrapperView: UIView!
    @IBOutlet weak var loadingView: UIActivityIndicatorView!

    private let userContentController = WKUserContentController()
    private let swipeToDismissByPositionThresholdHeight: CGFloat = 180
    private let swipeToDismissByVelocityThresholdHeight: CGFloat = 250
    private let swipeToDismissByVelocityThresholdVelocity: CGFloat = 1200
    private let swipeToZoomVelocityThreshold: CGFloat = 800

    private var swipeToZoomAnimator: UIViewPropertyAnimator?

    private var userScript = WKUserScript(source: """
        var imageElements = document.images;
        for(var i = 0; i < imageElements.length; i++) {
            var imageElement = imageElements[i];
            var intervalID = 0;
            var touchX = 0, touchY = 0;
            imageElement.ontouchstart = function(e) {
                e.preventDefault();
                intervalID = window.setInterval(
                    function() {
                        window.clearInterval(intervalID);
                        window.webkit.messageHandlers.ImageLongPressHandler.postMessage(e.target.src);
                    },
                    1000
                );
                touchX = e.touches[0].pageX
                touchY = e.touches[0].pageY
            };
            imageElement.ontouchmove = function(e) {
                var targetX = window.scrollX - (e.touches[0].pageX - touchX);
                var targetY = window.scrollY - (e.touches[0].pageY - touchY);
                window.scrollTo(targetX, targetY);
            };
            imageElement.ontouchend = function(e) {
                window.clearInterval(intervalID);
            };
            imageElement.ontouchcancel = function(e) {
                window.clearInterval(intervalID);
            }
        };
""", injectionTime: .atDocumentEnd, forMainFrameOnly: true)

    private lazy var webView: MixinWebView = {
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = .all
        config.preferences = WKPreferences()
        config.preferences.minimumFontSize = 12
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.userContentController = userContentController
        userContentController.add(self, name: MessageHandlerName.mixinContext)
        userContentController.add(self, name: MessageHandlerName.imageLongPress)
        userContentController.addUserScript(userScript)
        return MixinWebView(frame: .zero, configuration: config)
    }()

    private var conversationId = ""
    private var processLongPress = false

    override func awakeFromNib() {
        super.awakeFromNib()

        windowBackgroundColor = UIColor(white: 0.0, alpha: 0.3)
        webViewWrapperView.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        webView.allowsBackForwardNavigationGestures = true

        webView.scrollView.delegate = self
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.addObserver(self, forKeyPath: "title", options: .new, context: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: .UIKeyboardWillShow, object: nil)
    }

    override func zoomAnimation(targetHeight: CGFloat) {
        if targetHeight < webViewWrapperHeightConstraint.constant {
            webView.endEditing(true)
        }
        super.zoomAnimation(targetHeight: targetHeight)
    }

    override func zoomAction(_ sender: Any) {
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.ACTION_REFRESH, style: .default, handler: { [weak self](_) in
            guard let weakSelf = self, let url = weakSelf.webView.url else {
                return
            }
            weakSelf.webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10))
        }))
        alc.addAction(UIAlertAction(title: Localized.ACTION_OPEN_SAFARI, style: .default, handler: { [weak self](_) in
            guard let weakSelf = self, let requestUrl = weakSelf.webView.url else {
                return
            }
            UIApplication.shared.open(requestUrl, options: [:], completionHandler: nil)
            weakSelf.dismissPopupControllerAnimated()
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        UIApplication.currentActivity()?.present(alc, animated: true, completion: nil)
    }

    override func toggleZoomAction() {
        windowMaximum = !windowMaximum
        let targetHeight = windowMaximum ? maximumWebViewHeight : minimumWebViewHeight
        UIView.animate(withDuration: 0.25) {
            self.zoomAnimation(targetHeight: targetHeight)
        }
    }

    func presentPopupControllerAnimated(url: URL) {
        presentView()
        webView.load(URLRequest(url: url))
        loadingView.startAnimating()
        loadingView.isHidden = false
    }

    override func dismissPopupControllerAnimated() {
        webView.stopLoading()
        userContentController.removeScriptMessageHandler(forName: MessageHandlerName.mixinContext)
        userContentController.removeScriptMessageHandler(forName: MessageHandlerName.imageLongPress)
        dismissView()
    }

    @IBAction func backAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }

    @IBAction func panAction(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case.began:
            webView.endEditing(true)
            recognizer.setTranslation(.zero, in: self)
        case .changed:
            let targetHeight = webViewWrapperHeightConstraint.constant - recognizer.translation(in: self).y
            zoomAnimation(targetHeight: targetHeight)
            recognizer.setTranslation(.zero, in: self)
        case .ended, .cancelled, .failed:
            let shouldDismissByPosition = webViewWrapperHeightConstraint.constant < swipeToDismissByPositionThresholdHeight
            let shouldDismissByVelocity = webViewWrapperHeightConstraint.constant < swipeToDismissByVelocityThresholdHeight
                && recognizer.velocity(in: self).y > swipeToDismissByVelocityThresholdVelocity
            if shouldDismissByPosition || shouldDismissByVelocity {
                dismissPopupControllerAnimated()
            } else {
                if recognizer.velocity(in: self).y > swipeToZoomVelocityThreshold {
                    windowMaximum = true
                } else if recognizer.velocity(in: self).y < -swipeToZoomVelocityThreshold {
                    windowMaximum = false
                } else {
                    windowMaximum = !(webViewWrapperHeightConstraint.constant > minimumWebViewHeight + (maximumWebViewHeight - minimumWebViewHeight) / 2)
                }
                toggleZoomAction()
            }
        default:
            break
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        webView.removeObserver(self, forKeyPath: "title")
        webView.scrollView.delegate = nil
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let key = keyPath else {
            return
        }
        switch key {
        case "title":
            titleLabel.text = webView.title
            loadingView.stopAnimating()
            loadingView.isHidden = true
        default:
            break
        }
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        guard UIApplication.currentActivity()?.view.subviews.last == self, !windowMaximum else {
            return
        }
        toggleZoomAction()
    }
    
    class func instance(conversationId: String) -> WebWindow {
        let win = Bundle.main.loadNibNamed("WebWindow", owner: nil, options: nil)?.first as! WebWindow
        win.conversationId = conversationId
        return win
    }
    
}

extension WebWindow: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard !processLongPress, message.name == MessageHandlerName.imageLongPress, let urlString = message.body as? String, let url = URL(string: urlString) else {
            return
        }
        processLongPress = true
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.requestCachePolicy = .returnCacheDataElseLoad
        URLSession(configuration: sessionConfig).dataTask(with: url, completionHandler: { [weak self](data, response, error) in
            defer {
                self?.processLongPress = false
            }
            guard let data = data, let image = UIImage(data: data) else {
                return
            }
            self?.showImageMenu(image: image)
        }).resume()
    }

    private func showImageMenu(image: UIImage) {
        DispatchQueue.global().async {
            var qrcodeUrl: URL!
            if let ciImage = CIImage(image: image), let features = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil)?.features(in: ciImage) {
                for case let feature as CIQRCodeFeature in features {
                    guard let messageString = feature.messageString, let url = URL(string: messageString) else {
                        continue
                    }
                    qrcodeUrl = url
                    break
                }
            }
            DispatchQueue.main.async {
                let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                alc.addAction(UIAlertAction(title: Localized.CHAT_PHOTO_SAVE, style: .default, handler: { (_) in
                    PHPhotoLibrary.checkAuthorization { (authorized) in
                        guard authorized else {
                            return
                        }
                        PHPhotoLibrary.saveImageToLibrary(image: image)
                    }
                }))
                if qrcodeUrl != nil {
                    alc.addAction(UIAlertAction(title: Localized.SCAN_QR_CODE, style: .default, handler: { (_) in
                        if !UrlWindow.checkUrl(url: qrcodeUrl, clearNavigationStack: false) {

                        }
                    }))
                }
                alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
                UIApplication.currentActivity()?.present(alc, animated: true, completion: nil)
            }
        }
    }

}

extension WebWindow: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.isTracking && !scrollView.isDecelerating else {
            return
        }
        let newConstant = webViewWrapperHeightConstraint.constant + scrollView.contentOffset.y
        if newConstant <= maximumWebViewHeight {
            webViewWrapperHeightConstraint.constant = newConstant
            layoutIfNeeded()
            scrollView.contentOffset.y = 0
            let shouldMaximizeWindow = newConstant > minimumWebViewHeight + (maximumWebViewHeight - minimumWebViewHeight) / 2
            if windowMaximum != shouldMaximizeWindow {
                windowMaximum = shouldMaximizeWindow
            }
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        swipeToZoomAnimator?.stopAnimation(true)
        swipeToZoomAnimator = nil
        webViewWrapperHeightConstraint.constant = webViewWrapperView.frame.height
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let shouldDismissByPosition = webViewWrapperHeightConstraint.constant < swipeToDismissByPositionThresholdHeight
        let shouldDismissByVelocity = webViewWrapperHeightConstraint.constant < swipeToDismissByVelocityThresholdHeight
            && scrollView.panGestureRecognizer.velocity(in: scrollView).y > swipeToDismissByVelocityThresholdVelocity
        if shouldDismissByPosition || shouldDismissByVelocity {
            dismissPopupControllerAnimated()
        } else {
            if abs(velocity.y) > 0.01 {
                let suggestedWindowMaximum = velocity.y > 0
                if windowMaximum != suggestedWindowMaximum && (suggestedWindowMaximum || targetContentOffset.pointee.y < 0.1) {
                    windowMaximum = suggestedWindowMaximum
                }
            }
            webViewWrapperHeightConstraint.constant = windowMaximum ? maximumWebViewHeight : minimumWebViewHeight
            setNeedsLayout()
            let animator = UIViewPropertyAnimator(duration: 0.25, curve: .easeOut, animations: {
                self.layoutIfNeeded()
            })
            animator.addCompletion({ (_) in
                self.swipeToZoomAnimator = nil
            })
            animator.startAnimation()
            swipeToZoomAnimator = animator
        }
    }
    
}

extension WebWindow: WKNavigationDelegate {
    
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
            } else {
                UIApplication.trackError("WebWindow", action: "webview navigation canOpenURL false", userInfo: ["url": url.absoluteString])
            }
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }

}

extension WebWindow: WKUIDelegate {

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        if prompt == "MixinContext.getContext()" {
            completionHandler("{\"conversation_id\":\"\(conversationId)\"}")
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

extension WebWindow {
    
    enum MessageHandlerName {
        static let mixinContext = "MixinContext"
        static let imageLongPress = "ImageLongPressHandler"
    }
    
}
