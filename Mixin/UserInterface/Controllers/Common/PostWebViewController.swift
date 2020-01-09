import UIKit
import WebKit

class PostWebViewController: WebViewController {
    
    private let postContainerUrl = Bundle.main.url(forResource: "post", withExtension: "html")!
    
    private var markdown = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        showPageTitleConstraint.priority = .defaultLow
        webView.navigationDelegate = self
        let request = URLRequest(url: postContainerUrl)
        webView.load(request)
    }
    
    class func presentInstance(markdown: String, asChildOf parent: UIViewController) {
        let vc = PostWebViewController(nib: R.nib.webView)
        vc.markdown = markdown
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
    
}

extension PostWebViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        guard url != postContainerUrl else {
            decisionHandler(.allow)
            return
        }
        
        defer {
            decisionHandler(.cancel)
        }
        
        if UrlWindow.checkUrl(url: url, fromWeb: true) {
            return
        }
        guard let parent = parent else {
            return
        }
        MixinWebViewController.presentInstance(with: .init(conversationId: "", initialUrl: url), asChildOf: parent)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let isImageEnabled = "true"
        let escapedMarkdown = markdown.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? markdown
        let script = "window.showMarkdown('\(escapedMarkdown)', \(isImageEnabled));"
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
    
}
