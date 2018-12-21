import UIKit
import WebKit
import Alamofire
import Photos
import SwiftMessages

class WebViewController: UIViewController {
    
    private let queue = OperationQueue()
    private let mixinContext = "MixinContext"
    private let disableImageSelectionScriptString = """
    var style = document.createElement('style');
    style.innerHTML = 'img { -webkit-user-select: none; -webkit-touch-callout: none; }';
    document.head.appendChild(style)
    """
    
    private var imageLoadingRequest: DataRequest?
    
    var conversationId = ""
    
    var webView: WKWebView {
        return view as! WKWebView
    }
    
    override func loadView() {
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = .all
        config.preferences = WKPreferences()
        config.preferences.minimumFontSize = 12
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        let script = WKUserScript(source: disableImageSelectionScriptString,
                                  injectionTime: .atDocumentEnd,
                                  forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
        config.userContentController.add(self, name: mixinContext)
        view = WKWebView(frame: UIScreen.main.bounds, configuration: config)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction(_:)))
        longPressRecognizer.delegate = self
        webView.addGestureRecognizer(longPressRecognizer)
        webView.uiDelegate = self
        webView.navigationDelegate = self
    }
    
    @objc func longPressAction(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else {
            return
        }
        imageLoadingRequest?.cancel()
        let location = round(recognizer.location(in: webView))
        let script = "document.elementFromPoint(\(location.x), \(location.y)).src"
        webView.evaluateJavaScript(script) { (urlString, error) in
            guard error == nil, let urlString = urlString as? String, let url = URL(string: urlString) else {
                return
            }
            self.imageLoadingRequest = Alamofire.request(url).responseData(completionHandler: { [weak self] in
                guard case let .success(data) = $0.result, let image = UIImage(data: data) else {
                    return
                }
                self?.presentAlertController(for: image)
            })
        }
    }
    
    func load(url: URL) {
        webView.alpha = 0
        let request = URLRequest(url: url)
        webView.load(request)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.webView.alpha = 1
        }
    }
    
    func unload() {
        imageLoadingRequest?.cancel()
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: mixinContext)
    }
    
    private func presentAlertController(for image: UIImage) {
        queue.cancelAllOperations()
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self] in
            var qrCodeUrl: URL?
            if let ciImage = CIImage(image: image), let features = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil)?.features(in: ciImage) {
                for case let feature as CIQRCodeFeature in features {
                    guard let messageString = feature.messageString, let url = URL(string: messageString) else {
                        continue
                    }
                    qrCodeUrl = url
                    break
                }
            }
            DispatchQueue.main.sync {
                guard !op.isCancelled, let weakSelf = self else {
                    return
                }
                let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                alert.addAction(UIAlertAction(title: Localized.CHAT_PHOTO_SAVE, style: .default, handler: { (_) in
                    PHPhotoLibrary.checkAuthorization { (authorized) in
                        guard authorized else {
                            return
                        }
                        PHPhotoLibrary.saveImageToLibrary(image: image)
                    }
                }))
                if let url = qrCodeUrl {
                    alert.addAction(UIAlertAction(title: Localized.SCAN_QR_CODE, style: .default, handler: { (_) in
                        if !UrlWindow.checkUrl(url: url, clearNavigationStack: false) {
                            SwiftMessages.showToast(message: Localized.NOT_MIXIN_QR_CODE, backgroundColor: .hintRed)
                        }
                    }))
                }
                alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
                weakSelf.present(alert, animated: true, completion: nil)
            }
        }
        queue.addOperation(op)
    }
    
}

extension WebViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
}

extension WebViewController: WKUIDelegate {
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        if prompt == "MixinContext.getContext()" {
            completionHandler("{\"conversation_id\":\"\(conversationId)\"}")
        } else {
            completionHandler(nil)
        }
    }
    
}

extension WebViewController: WKNavigationDelegate {
    
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

extension WebViewController: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
    }
    
}

extension WebViewController: ConversationExtensionViewController {
    
    var canBeFullsized: Bool {
        return true
    }
    
}
