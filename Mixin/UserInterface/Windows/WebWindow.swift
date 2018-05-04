import Foundation
import WebKit

class WebWindow: ZoomWindow {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var webViewWrapperView: UIView!
    @IBOutlet weak var loadingView: UIActivityIndicatorView!

    private let userContentController = WKUserContentController()
    private let swipeZoomVelocityThreshold: CGFloat = 800

    private lazy var webView: MixinWebView = {
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = .all
        config.preferences = WKPreferences()
        config.preferences.minimumFontSize = 12
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.userContentController = userContentController
        userContentController.add(self, name: "MixinContext")
        return MixinWebView(frame: .zero, configuration: config)
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

    func presentPopupControllerAnimated(url: URL) {
        super.presentPopupControllerAnimated()
        webView.load(URLRequest(url: url))
        loadingView.startAnimating()
        loadingView.isHidden = false
    }

    override func dismissPopupControllerAnimated() {
        webView.stopLoading()
        userContentController.removeScriptMessageHandler(forName: "MixinContext")
        super.dismissPopupControllerAnimated()
    }

    @IBAction func backAction(_ sender: Any) {
        dismissPopupControllerAnimated()
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
        guard UIApplication.shared.keyWindow?.subviews.last == self, !windowMaximum else {
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
                zoomButton.setImage(shouldMaximizeWindow ? #imageLiteral(resourceName: "ic_titlebar_min") : #imageLiteral(resourceName: "ic_titlebar_max"), for: .normal)
            }
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if abs(velocity.y) > 0.01 {
            let suggestedWindowMaximum = velocity.y > 0
            if windowMaximum != suggestedWindowMaximum && (suggestedWindowMaximum || targetContentOffset.pointee.y < 0.1) {
                windowMaximum = suggestedWindowMaximum
                zoomButton.setImage(windowMaximum ? #imageLiteral(resourceName: "ic_titlebar_min") : #imageLiteral(resourceName: "ic_titlebar_max"), for: .normal)
            }
        }
        webViewWrapperHeightConstraint.constant = windowMaximum ? maximumWebViewHeight : minimumWebViewHeight
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
            self.layoutIfNeeded()
        }, completion: nil)
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
