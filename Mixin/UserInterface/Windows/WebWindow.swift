import Foundation
import WebKit
import Photos
import UIKit.UIGestureRecognizerSubclass
import SwiftMessages

class WebWindow: BottomSheetView {

    @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var moreButton: UIButton!
    @IBOutlet weak var webViewWrapperView: UIView!
    @IBOutlet weak var loadingView: UIActivityIndicatorView!
    @IBOutlet weak var edgePanGestureRecognizer: WebViewScreenEdgePanGestureRecognizer!
    @IBOutlet weak var longPressGestureRecognizer: UILongPressGestureRecognizer!
    
    @IBOutlet weak var titleHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var webViewWrapperHeightConstraint: NSLayoutConstraint!
    
    weak var controller: (UIViewController & StatusBarStyleSwitchableViewController)?

    private let swipeToDismissByPositionThresholdHeight: CGFloat = 180
    private let swipeToDismissByVelocityThresholdHeight: CGFloat = 250
    private let swipeToDismissByVelocityThresholdVelocity: CGFloat = 1200
    private let swipeToZoomVelocityThreshold: CGFloat = 800
    private let edgePanToDismissDecisionDistance: CGFloat = 50
    private let disableImageSelectionScriptString = """
    var style = document.createElement('style');
    style.innerHTML = 'img { -webkit-user-select: none; -webkit-touch-callout: none; }';
    document.head.appendChild(style)
    """
    
    private var swipeToZoomAnimator: UIViewPropertyAnimator?
    private var conversationId = ""
    private var isMaximized = false
    private var webViewTitleObserver: NSKeyValueObservation?
    private var minimumWebViewHeight: CGFloat = 428
    private var scrollViewBeganDraggingOffset = CGPoint.zero
    private var imageDownloadTask: URLSessionDataTask?
    
    private lazy var maximumWebViewHeight: CGFloat = {
        let minStatusBarHeight: CGFloat = 20
        if #available(iOS 11.0, *), let window = AppDelegate.current.window {
            return window.frame.height - max(window.safeAreaInsets.top, minStatusBarHeight) - window.safeAreaInsets.bottom
        } else {
            return frame.height - titleHeightConstraint.constant - minStatusBarHeight
        }
    }()
    private lazy var medianWebViewHeight = minimumWebViewHeight + (maximumWebViewHeight - minimumWebViewHeight) / 2
    private lazy var webView: MixinWebView = {
        let disableImageSelectionScript = WKUserScript(source: disableImageSelectionScriptString, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = .all
        config.preferences = WKPreferences()
        config.preferences.minimumFontSize = 12
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.userContentController.add(self, name: MessageHandlerName.mixinContext)
        config.userContentController.addUserScript(disableImageSelectionScript)
        return MixinWebView(frame: .zero, configuration: config)
    }()
    private lazy var imageDownloadSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()
    
    var webViewHeight: CGFloat {
        get {
            return webViewWrapperHeightConstraint.constant
        }
        set {
            let oldValue = webViewHeight
            webViewWrapperHeightConstraint.constant = newValue
            layoutIfNeeded()
            if newValue < oldValue {
                webView.endEditing(true)
            }
            updateBackgroundColor()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        layoutIfNeeded()
        minimumWebViewHeight = webViewWrapperHeightConstraint.constant
        windowBackgroundColor = UIColor.black.withAlphaComponent(BackgroundAlpha.halfsized)
        webViewWrapperView.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.delegate = self
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.panGestureRecognizer.require(toFail: edgePanGestureRecognizer)
        webViewTitleObserver = webView.observe(\.title) { [weak self] (_, _) in
            self?.updateTitle()
        }
        dismissButton.imageView?.contentMode = .scaleAspectFit
        moreButton.imageView?.contentMode = .scaleAspectFit
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: .UIKeyboardWillShow, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        webView.scrollView.delegate = nil
    }
    
    override func dismissPopupControllerAnimated() {
        imageDownloadTask?.cancel()
        controller?.statusBarStyle = .default
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: MessageHandlerName.mixinContext)
        CATransaction.perform(blockWithTransaction: {
            dismissView()
        }) {
            self.controller?.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            self.removeFromSuperview()
        }
    }
    
    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer == longPressGestureRecognizer {
            return true
        } else {
            return super.gestureRecognizer(gestureRecognizer, shouldReceive: touch)
        }
    }
    
    @IBAction func moreAction(_ sender: Any) {
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
    
    @IBAction func dismissAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }

    @IBAction func panAction(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case.began:
            webView.endEditing(true)
            recognizer.setTranslation(.zero, in: self)
        case .changed:
            webViewHeight -= recognizer.translation(in: self).y
            recognizer.setTranslation(.zero, in: self)
        case .ended, .cancelled, .failed:
            let shouldDismissByPosition = webViewHeight < swipeToDismissByPositionThresholdHeight
            let shouldDismissByVelocity = webViewHeight < swipeToDismissByVelocityThresholdHeight
                && recognizer.velocity(in: self).y > swipeToDismissByVelocityThresholdVelocity
            if shouldDismissByPosition || shouldDismissByVelocity {
                dismissPopupControllerAnimated()
            } else {
                let shouldMaximize: Bool
                if recognizer.velocity(in: self).y > swipeToZoomVelocityThreshold {
                    shouldMaximize = false
                } else if recognizer.velocity(in: self).y < -swipeToZoomVelocityThreshold {
                    shouldMaximize = true
                } else {
                    shouldMaximize = webViewHeight > minimumWebViewHeight + (maximumWebViewHeight - minimumWebViewHeight) / 2
                }
                setIsMaximizedAnimated(shouldMaximize)
                controller?.statusBarStyle = shouldMaximize ? .lightContent : .default
            }
        default:
            break
        }
    }
    
    @IBAction func screenEdgePanAction(_ recognizer: WebViewScreenEdgePanGestureRecognizer) {
        switch recognizer.state {
        case .changed:
            popupView.transform = CGAffineTransform(scaleX: 1 - 0.2 * recognizer.fractionComplete,
                                                    y: 1 - 0.2 * recognizer.fractionComplete)
            if isMaximized {
                let alpha = BackgroundAlpha.fullsized + (BackgroundAlpha.halfsized - BackgroundAlpha.fullsized) * recognizer.fractionComplete
                backgroundColor = UIColor.black.withAlphaComponent(alpha)
            }
        case .ended:
            UIView.animate(withDuration: 0.25, animations: {
                self.popupView.transform = .identity
            })
            dismissPopupControllerAnimated()
        case .cancelled:
            UIView.animate(withDuration: 0.25, animations: {
                self.popupView.transform = .identity
                if self.isMaximized {
                    self.backgroundColor = .black
                }
            })
        default:
            break
        }
    }
    
    @IBAction func longPressAction(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else {
            return
        }
        imageDownloadTask?.cancel()
        let location = round(recognizer.location(in: webView))
        let script = "document.elementFromPoint(\(location.x), \(location.y)).src"
        webView.evaluateJavaScript(script) { (urlString, error) in
            guard error == nil, let urlString = urlString as? String, let url = URL(string: urlString) else {
                return
            }
            self.imageDownloadTask = self.imageDownloadSession.dataTask(with: url, completionHandler: { [weak self] (data, response, error) in
                guard let data = data, let image = UIImage(data: data) else {
                    return
                }
                self?.presentAlertController(for: image)
            })
            self.imageDownloadTask?.resume()
        }
    }
    
    @objc func keyboardWillShow(_ notification: Notification) {
        guard UIApplication.currentActivity()?.view.subviews.last == self, !isMaximized else {
            return
        }
        setIsMaximizedAnimated(true)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func presentPopupControllerAnimated(url: URL) {
        presentView()
        webView.load(URLRequest(url: url))
        loadingView.startAnimating()
        loadingView.isHidden = false
        controller?.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    
    class func instance(conversationId: String) -> WebWindow {
        let win = Bundle.main.loadNibNamed("WebWindow", owner: nil, options: nil)?.first as! WebWindow
        win.conversationId = conversationId
        return win
    }
    
}

extension WebWindow: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    
    }

}

extension WebWindow: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isTracking {
            if scrollView.panGestureRecognizer.velocity(in: scrollView).y < 0 {
                let newHeight = webViewHeight + (scrollView.contentOffset.y - scrollViewBeganDraggingOffset.y)
                if newHeight <= maximumWebViewHeight {
                    webViewHeight = newHeight
                    scrollView.contentOffset = scrollViewBeganDraggingOffset
                    isMaximized = newHeight > medianWebViewHeight
                }
            } else {
                scrollViewBeganDraggingOffset = scrollView.contentOffset
                if scrollView.contentOffset.y < 0.1 {
                    webViewHeight += scrollView.contentOffset.y
                    scrollView.contentOffset.y = 0
                    isMaximized = webViewHeight > medianWebViewHeight
                }
            }
        }
        controller?.statusBarStyle = maximumWebViewHeight - titleHeightConstraint.constant - webViewHeight < 1 ? .lightContent : .default
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        swipeToZoomAnimator?.stopAnimation(true)
        swipeToZoomAnimator = nil
        scrollViewBeganDraggingOffset = scrollView.contentOffset
        webViewHeight = webViewWrapperView.frame.height
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let shouldDismissByPosition = webViewHeight < swipeToDismissByPositionThresholdHeight
        let shouldDismissByVelocity = webViewHeight < swipeToDismissByVelocityThresholdHeight
            && scrollView.panGestureRecognizer.velocity(in: scrollView).y > swipeToDismissByVelocityThresholdVelocity
        if shouldDismissByPosition || shouldDismissByVelocity {
            dismissPopupControllerAnimated()
        } else {
            if abs(velocity.y) > 0.01 {
                let isDraggingUp = velocity.y > 0
                if isMaximized != isDraggingUp && (isDraggingUp || targetContentOffset.pointee.y < 0.1) {
                    isMaximized = isDraggingUp
                }
            }
            let isShowingTitleBar = maximumWebViewHeight - self.webViewHeight > 5
            let shouldShowTitleBar = velocity.y < 0 || (velocity.y == 0 && isShowingTitleBar)
            let webViewHeight = (isMaximized ? maximumWebViewHeight : minimumWebViewHeight) - (shouldShowTitleBar ? titleHeightConstraint.constant : 0)
            var newContentOffsetY: CGFloat?
            let heightDifference = (webViewHeight - self.webViewHeight)
            let shouldAdjustContentOffset = velocity.y == 0
                && isMaximized
                && (webViewHeight != self.webViewHeight)
                && heightDifference <= titleHeightConstraint.constant
            if shouldAdjustContentOffset {
                newContentOffsetY = scrollView.contentOffset.y - heightDifference
            }
            webViewWrapperHeightConstraint.constant = webViewHeight
            let animator = UIViewPropertyAnimator(duration: 0.25, curve: .easeOut, animations: {
                self.layoutIfNeeded()
                self.updateBackgroundColor()
                if let newContentOffsetY = newContentOffsetY {
                    scrollView.contentOffset.y = newContentOffsetY
                }
            })
            animator.addCompletion({ (_) in
                self.swipeToZoomAnimator = nil
                self.controller?.statusBarStyle = self.isMaximized ? .lightContent : .default
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
    }
    
    enum BackgroundAlpha {
        static let halfsized: CGFloat = 0.3
        static let fullsized: CGFloat = 1
    }
    
    private func updateTitle() {
        titleLabel.text = webView.title
        loadingView.stopAnimating()
        loadingView.isHidden = true
    }
    
    private func setIsMaximizedAnimated(_ isMaximized: Bool) {
        self.isMaximized = isMaximized
        let newHeight = isMaximized ? maximumWebViewHeight : minimumWebViewHeight
        controller?.statusBarStyle = isMaximized ? .lightContent : .default
        UIView.animate(withDuration: 0.25) {
            self.webViewHeight = newHeight
        }
    }
    
    private func updateBackgroundColor() {
        let alpha = (webViewHeight - minimumWebViewHeight) * (BackgroundAlpha.fullsized - BackgroundAlpha.halfsized) / (maximumWebViewHeight - minimumWebViewHeight) + BackgroundAlpha.halfsized
        backgroundColor = UIColor.black.withAlphaComponent(max(BackgroundAlpha.halfsized, alpha))
    }
    
    private func presentAlertController(for image: UIImage) {
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
                            SwiftMessages.showToast(message: Localized.NOT_MIXIN_QR_CODE, backgroundColor: .hintRed)
                        }
                    }))
                }
                alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
                UIApplication.currentActivity()?.present(alc, animated: true, completion: nil)
            }
        }
    }
    
}

class WebViewScreenEdgePanGestureRecognizer: UIScreenEdgePanGestureRecognizer {
    
    static let decisionDistance: CGFloat = UIScreen.main.bounds.width / 4

    private(set) var fractionComplete: CGFloat = 0
    
    private var beganTranslation = CGPoint.zero
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        fractionComplete = 0
        super.touchesBegan(touches, with: event)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let translation = self.translation(in: view)
        var shouldEnd = false
        fractionComplete = min(1, max(0, translation.x / WebViewScreenEdgePanGestureRecognizer.decisionDistance))
        if translation.x > WebViewScreenEdgePanGestureRecognizer.decisionDistance {
            shouldEnd = true
        }
        super.touchesMoved(touches, with: event)
        if shouldEnd {
            state = .ended
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if fractionComplete > 0.99 {
            super.touchesEnded(touches, with: event)
        } else {
            super.touchesCancelled(touches, with: event)
        }
    }
    
}
