import UIKit
import MixinServices
import WebKit

class PostWebViewController: WebViewController {
    
    private var message: Message!
    private var html: String?
    
    override var webViewConfiguration: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = .link
        return config
    }
    
    class func presentInstance(message: Message, asChildOf parent: UIViewController) {
        let vc = PostWebViewController(nib: R.nib.fullscreenPopupView)
        vc.message = message
        vc.presentAsChild(of: parent, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        showPageTitleConstraint.priority = .defaultLow
        webView.navigationDelegate = self
        guard let content = message.content else {
            return
        }
        DispatchQueue.global().async {
            let html = MarkdownConverter.htmlString(from: content, richFormat: true)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }
                self.html = html
                self.webView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
            }
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *), traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBackground(pageThemeColor: .background)
        }
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory, let html = html {
            webView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
        }
    }
    
    override func moreAction(_ sender: Any) {
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: R.string.localizable.chat_message_menu_forward(), style: .default, handler: { (_) in
            let vc = MessageReceiverViewController.instance(content: .message(self.message))
            self.navigationController?.pushViewController(vc, animated: true)
        }))
        controller.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        present(controller, animated: true, completion: nil)
    }
    
}

extension PostWebViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        if url == Bundle.main.bundleURL {
            decisionHandler(.allow)
            return
        }
        
        defer {
            decisionHandler(.cancel)
        }
        
        if UrlWindow.checkUrl(url: url) {
            return
        }
        if let parent = parent {
            MixinWebViewController.presentInstance(with: .init(conversationId: "", initialUrl: url), asChildOf: parent)
        }
    }
    
}
