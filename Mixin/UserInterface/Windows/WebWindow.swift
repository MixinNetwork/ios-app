import Foundation
import WebKit
import Photos
import UIKit.UIGestureRecognizerSubclass
import FirebaseMLCommon
import FirebaseMLVision
import Bugsnag

class WebWindow: BottomSheetView {

    @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var webViewWrapperView: UIView!
    @IBOutlet weak var longPressGestureRecognizer: UILongPressGestureRecognizer!
    @IBOutlet weak var edgePanGestureRecognizer: WebViewScreenEdgePanGestureRecognizer!
    
    @IBOutlet weak var titleHeightConstraint: NSLayoutConstraint!
    
    var usePageTitle = true
    
    private let disableImageSelectionScriptString = """
    var style = document.createElement('style');
    style.innerHTML = 'img { -webkit-user-select: none; -webkit-touch-callout: none; }';
    document.head.appendChild(style)
    """
    
    private var conversationId = ""
    private var webViewTitleObserver: NSKeyValueObservation?
    private var imageDownloadTask: URLSessionDataTask?
    private var titleBarDidBecomeVisible = true
    
    private lazy var webView: MixinWebView = {
        let disableImageSelectionScript = WKUserScript(source: disableImageSelectionScriptString, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = .all
        config.preferences = WKPreferences()
        config.preferences.minimumFontSize = 12
        config.preferences.javaScriptEnabled = true
        config.allowsInlineMediaPlayback = true
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

    private lazy var qrcodeDetector = Vision.vision().barcodeDetector(options: VisionBarcodeDetectorOptions(formats: .qrCode))
    
    override func awakeFromNib() {
        super.awakeFromNib()
        layoutIfNeeded()
        windowBackgroundColor = UIColor.black.withAlphaComponent(0.3)
        webViewWrapperView.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.panGestureRecognizer.require(toFail: edgePanGestureRecognizer)
        webViewTitleObserver = webView.observe(\.title) { [weak self] (_, _) in
            self?.updateTitle()
        }
        dismissButton.imageView?.contentMode = .scaleAspectFit
    }
    
    override func didMoveToSuperview() {
        guard let navigationController = UIApplication.rootNavigationController() else {
            return
        }
        navigationController.interactivePopGestureRecognizer?.isEnabled = superview == nil
    }
    
    override func dismissPopupControllerAnimated() {
        imageDownloadTask?.cancel()
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: MessageHandlerName.mixinContext)
        CATransaction.perform(blockWithTransaction: {
            dismissView()
        }) {
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
    
    @IBAction func moreAction(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else {
            return
        }
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
    
    @IBAction func screenEdgePanAction(_ recognizer: WebViewScreenEdgePanGestureRecognizer) {
        switch recognizer.state {
        case .changed:
            popupView.transform = CGAffineTransform(scaleX: 1 - 0.2 * recognizer.fractionComplete,
                                                    y: 1 - 0.2 * recognizer.fractionComplete)
        case .ended:
            UIView.animate(withDuration: 0.25, animations: {
                self.popupView.transform = .identity
            })
            dismissPopupControllerAnimated()
        case .cancelled:
            UIView.animate(withDuration: 0.25, animations: {
                self.popupView.transform = .identity
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
                DispatchQueue.main.async {
                    self?.presentAlertController(for: image)
                }
            })
            self.imageDownloadTask?.resume()
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func presentPopupControllerAnimated(url: URL) {
        presentView()
        webView.load(URLRequest(url: url))
    }
    
    class func instance(conversationId: String, app: App? = nil) -> WebWindow {
        let win = Bundle.main.loadNibNamed("WebWindow", owner: nil, options: nil)?.first as! WebWindow
        win.conversationId = conversationId
        if let app = app {
            if let iconUrl = URL(string: app.iconUrl) {
                win.iconImageView.isHidden = false
                win.iconImageView.sd_setImage(with: iconUrl, completed: nil)
            }
            win.usePageTitle = false
            win.titleLabel.text = app.name
        }
        return win
    }
    
}

extension WebWindow: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    
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
    
    private func updateTitle() {
        guard usePageTitle else {
            return
        }
        titleLabel.text = webView.title
    }
    
    private func presentAlertController(for image: UIImage) {
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.CHAT_PHOTO_SAVE, style: .default, handler: { (_) in
            PHPhotoLibrary.checkAuthorization { (authorized) in
                guard authorized else {
                    return
                }
                PHPhotoLibrary.saveImageToLibrary(image: image)
            }
        }))

        qrcodeDetector.detect(in: VisionImage(image: image), completion: { (features, error) in
            if error == nil, let qrcodeText = features?.first?.url?.url, let qrcodeUrl = URL(string: qrcodeText) {
                alc.addAction(UIAlertAction(title: Localized.SCAN_QR_CODE, style: .default, handler: { (_) in
                    if !UrlWindow.checkUrl(url: qrcodeUrl, clearNavigationStack: false) {
                        showHud(style: .error, text: Localized.NOT_MIXIN_QR_CODE)
                    }
                }))
            }

            alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
            UIApplication.currentActivity()?.present(alc, animated: true, completion: nil)

        })
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
