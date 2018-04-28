import Foundation
import WebKit

class DAppWebWindow: ZoomWindow {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var webViewWrapperView: UIView!
    @IBOutlet weak var loadingView: UIActivityIndicatorView!
    @IBOutlet weak var panGestureRecognizableView: UIView!

    private let userContentController = WKUserContentController()
    private let swipeZoomVelocityThreshold: CGFloat = 800

    private lazy var webView: DAppWebView = {
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = .all
        config.preferences = WKPreferences()
        config.preferences.minimumFontSize = 12
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.userContentController = userContentController
        userContentController.add(self, name: "MixinContext")
        return DAppWebView(frame: .zero, configuration: config)
    }()

    private var conversationId = ""

    override func awakeFromNib() {
        super.awakeFromNib()

        windowBackgroundColor = UIColor(white: 0.0, alpha: 0.3)
        webViewWrapperView.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.addObserver(self, forKeyPath: "title", options: .new, context: nil)

        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panAction(_:)))
        panGestureRecognizableView.addGestureRecognizer(panRecognizer)
        
        NotificationCenter.default.addObserver(forName: .UIKeyboardWillShow, object: nil, queue: .main) { [weak self](_) in
            guard let weakSelf = self, UIApplication.shared.keyWindow?.subviews.last == weakSelf, !weakSelf.windowMaximum else {
                return
            }
            weakSelf.toggleZoomAction()
        }
    }

    override func zoomAnimation(targetHeight: CGFloat) {
        if targetHeight < webViewWrapperHeightConstraint.constant {
            webView.endEditing(true)
        }
        super.zoomAnimation(targetHeight: targetHeight)
    }

    func presentPopupControllerAnimated(url: URL) {
        super.presentPopupControllerAnimated()
        webView.load(URLRequest(url: url))
        loadingView.startAnimating()
        loadingView.isHidden = false
    }

    override func dismissPopupControllerAnimated() {
        webView.stopLoading()
        super.dismissPopupControllerAnimated()
    }

    @IBAction func backAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }
    
    @objc func panAction(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case.began:
            webView.endEditing(true)
            recognizer.setTranslation(.zero, in: self)
        case .changed:
            let targetHeight = webViewWrapperHeightConstraint.constant - recognizer.translation(in: self).y
            zoomAnimation(targetHeight: targetHeight)
            recognizer.setTranslation(.zero, in: self)
        case .ended, .cancelled, .failed:
            if recognizer.velocity(in: self).y > swipeZoomVelocityThreshold {
                windowMaximum = true
            } else if recognizer.velocity(in: self).y < -swipeZoomVelocityThreshold {
                windowMaximum = false
            } else {
                windowMaximum = !(webViewWrapperHeightConstraint.constant > minimumWebViewHeight + (maximumWebViewHeight - minimumWebViewHeight) / 2)
            }
            toggleZoomAction()
        default:
            break
        }
    }

    deinit {
        userContentController.removeScriptMessageHandler(forName: "MixinContext")
        webView.removeObserver(self, forKeyPath: "title")
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

    class func instance(conversationId: String) -> DAppWebWindow {
        let win = Bundle.main.loadNibNamed("DAppWebWindow", owner: nil, options: nil)?.first as! DAppWebWindow
        win.conversationId = conversationId
        return win
    }
}

extension DAppWebWindow: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    }

}

extension DAppWebWindow: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if DAppUrlWindow.checkUrl(url: url, fromWeb: true) {
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
                UIApplication.trackError("DAppWebWindow", action: "webview navigation canOpenURL false", userInfo: ["url": url.absoluteString])
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

extension DAppWebWindow: WKUIDelegate {

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
