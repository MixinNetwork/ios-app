import UIKit
import WebKit
import MixinServices

final class BuyTokenWebViewController: PopupTitledWebViewController {
    
    private var isMessageHandlerAdded = true
    
    private lazy var messageHandler = WebViewMessageHandler(delegate: self)
    
    deinit {
        Logger.general.debug(category: "BuyToken", message: "WebViewController deinited")
    }
    
    override func replaceWebView(configuration: WKWebViewConfiguration) {
        configuration.allowsInlineMediaPlayback = true
        for name in WebViewMessageHandler.Name.allCases.map(\.rawValue) {
            configuration.userContentController.add(messageHandler, name: name)
        }
        super.replaceWebView(configuration: configuration)
        webView.uiDelegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !isMessageHandlerAdded {
            for name in WebViewMessageHandler.Name.allCases.map(\.rawValue) {
                webView.configuration.userContentController.add(messageHandler, name: name)
            }
            isMessageHandlerAdded = true
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let webView, isMessageHandlerAdded {
            let controller = webView.configuration.userContentController
            WebViewMessageHandler.Name.allCases.map(\.rawValue)
                .forEach(controller.removeScriptMessageHandler(forName:))
            isMessageHandlerAdded = false
        }
    }
    
}

extension BuyTokenWebViewController: WKUIDelegate {
    
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        for name in WebViewMessageHandler.Name.allCases.map(\.rawValue) {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: name)
        }
        replaceWebView(configuration: configuration)
        self.webView.load(navigationAction.request)
        return nil
    }
    
}

extension BuyTokenWebViewController: WebViewMessageHandler.Delegate {
    
    func webViewMessageHander(_ handler: WebViewMessageHandler, didReceiveMessage message: WebViewMessageHandler.Message) {
        switch message {
        case .reloadTheme:
            break
        case .close:
            presentingViewController?.dismiss(animated: true)
        case .getTIPAddress(let callback):
            webView.evaluateJavaScript(callback)
        case .tipSign(let callback):
            webView.evaluateJavaScript(callback)
        case .getAssets:
            break
        case .web3Bridge:
            break
        case .signBotSignature(let callback):
            webView.evaluateJavaScript(callback)
        }
    }
    
    func webViewMessageHanderGetCurrentURL(_ handler: WebViewMessageHandler) -> URL? {
        webView.url
    }
    
}
