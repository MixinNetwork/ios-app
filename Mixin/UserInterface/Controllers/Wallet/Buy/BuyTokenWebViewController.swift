import UIKit
import WebKit

final class BuyTokenWebViewController: PopupTitledWebViewController {
    
    override func replaceWebView(configuration: WKWebViewConfiguration) {
        configuration.allowsInlineMediaPlayback = true
        super.replaceWebView(configuration: configuration)
        webView.uiDelegate = self
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
