import UIKit
import WebKit
import PDFKit
import MixinServices

class PostWebViewController: WebViewController {
    
    private var message: Message!
    private var pageTitle: String?
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
            let title = MarkdownConverter.attributedString(from: content, maxNumberOfCharacters: 20, maxNumberOfLines: 1).string.trimmingCharacters(in: .newlines)
            let html = MarkdownConverter.htmlString(from: content, richFormat: true)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }
                if !title.isEmpty {
                    self.pageTitle = title
                }
                self.html = html
                self.webView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
            }
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBackground(pageThemeColor: .background, measureDarknessWithUserInterfaceStyle: true)
        }
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory, let html = html {
            webView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
        }
    }
    
    override func moreAction(_ sender: Any) {
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: R.string.localizable.forward(), style: .default, handler: { (_) in
            let vc = MessageReceiverViewController.instance(content: .message(self.message))
            self.navigationController?.pushViewController(vc, animated: true)
        }))
        if let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            controller.addAction(UIAlertAction(title: R.string.localizable.export(), style: .default, handler: { _ in
                self.exportAsPDF(to: url)
            }))
        }
        controller.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
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

extension PostWebViewController {
    
    private class WebViewRenderer: UIPrintPageRenderer {
        
        override var paperRect: CGRect {
            pageBounds
        }
        
        override var printableRect: CGRect {
            documentBounds
        }
        
        private let pageBounds: CGRect
        private let documentBounds: CGRect
        private let horizontalMargin: CGFloat = 50
        
        fileprivate init(webView: WKWebView, pageBounds: CGRect) {
            self.pageBounds = pageBounds
            let documentCanvasSize = CGSize(width: pageBounds.width - horizontalMargin * 2,
                                            height: .greatestFiniteMagnitude)
            let documentHeight = webView.sizeThatFits(documentCanvasSize).height
            self.documentBounds = CGRect(x: horizontalMargin,
                                         y: 0,
                                         width: documentCanvasSize.width,
                                         height: documentHeight)
            super.init()
            addPrintFormatter(webView.viewPrintFormatter(), startingAtPageAt: 0)
            headerHeight = 35
            footerHeight = 100
        }
        
    }
    
    private func exportAsPDF(to cacheURL: URL) {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        
        let filename = (pageTitle ?? R.string.localizable.post()) + ExtensionName.pdf.withDot
        let url = cacheURL.appendingPathComponent(filename)
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792) // 8.5 by 11 inches according to UIGraphicsBeginPDFContextToFile(_:_:_:)
        let renderer = WebViewRenderer(webView: webView, pageBounds: pageBounds)
        
        // Dispatch time consuming procedure to next RunLoop to avoid explicit calling of [CATransaction flush]
        DispatchQueue.main.async {
            var success = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if success {
                    hud.hide()
                    let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    activity.completionWithItemsHandler = { (_, completed, _, _) in
                        try? FileManager.default.removeItem(at: url)
                        guard completed else {
                            return
                        }
                        if AppGroupUserDefaults.User.hasRestoreUploadAttachment {
                            AppGroupUserDefaults.User.hasRestoreUploadAttachment = false
                            JobService.shared.restoreUploadJobs()
                        }
                        if AppGroupUserDefaults.User.reloadConversation {
                            AppGroupUserDefaults.User.reloadConversation = false
                            UIApplication.currentConversationViewController()?.dataSource.reload()
                        }
                    }
                    self.present(activity, animated: true, completion: nil)
                } else {
                    try? FileManager.default.removeItem(at: url)
                    hud.set(style: .error, text: R.string.localizable.export_failed())
                    hud.scheduleAutoHidden()
                }
            }
            
            do {
                try UIGraphicsPDFRenderer(bounds: pageBounds).writePDF(to: url) { ctx in
                    for page in 0..<renderer.numberOfPages {
                        ctx.beginPage()
                        renderer.drawPage(at: page, in: ctx.pdfContextBounds)
                    }
                }
                success = true
            } catch {
                success = false
            }
        }
    }
    
}
