import UIKit
import WebKit

final class BuyTokenWebViewController: PopupTitledWebViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webView.uiDelegate = self
    }
    
    override func replaceWebView(configuration: WKWebViewConfiguration) {
        configuration.allowsInlineMediaPlayback = true
        super.replaceWebView(configuration: configuration)
    }
    
}

extension BuyTokenWebViewController: WKUIDelegate {
    
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        replaceWebView(configuration: configuration)
        self.webView.load(navigationAction.request)
        return nil
    }
    
}
