import UIKit
import WebKit

class ReCaptchaManager: NSObject {
    
    static let shared = ReCaptchaManager()
    
    var webView: WKWebView?
    var reCaptchaViewController: ReCaptchaViewController?
    
    private let messageHandlerName = "recaptcha"
    private let executeReCaptchaJS = "gReCaptchaExecute();"
    private let scriptURL = "https://www.recaptcha.net/recaptcha/api.js"
    private let baseURL = URL(string: "https://api.mixin.one/")!
    private let timeoutInterval: TimeInterval = 10
    
    private lazy var htmlFilePath = Bundle.main.path(forResource: "recaptcha", ofType: ExtensionName.html.rawValue)
    private weak var requestingViewController: UIViewController?
    private var completion: CompletionCallback?
    private var timer: Timer?
    
    func validate(onViewController viewController: UIViewController, completion: @escaping CompletionCallback) {
        guard let htmlFilePath = htmlFilePath, let htmlString = try? String(contentsOfFile: htmlFilePath), let key = MixinKeys.reCaptcha else {
            assertionFailure("Failed to load reCAPTCHA html. Probably due to missing of Mixin-Keys.plist")
            return
        }
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: messageHandlerName)
        let webView = WKWebView(frame: UIScreen.main.bounds, configuration: config)
        webView.frame.origin.y = UIScreen.main.bounds.height
        UIApplication.shared.keyWindow?.addSubview(webView)
        let keyReplacedHTMLString = htmlString
            .replacingOccurrences(of: Replacement.apiKey, with: key)
            .replacingOccurrences(of: Replacement.scriptURL, with: scriptURL)
        webView.loadHTMLString(keyReplacedHTMLString, baseURL: baseURL)
        self.webView = webView
        self.requestingViewController = viewController
        self.completion = completion
        timer = Timer.scheduledTimer(withTimeInterval: timeoutInterval, repeats: false, block: { [weak self](_) in
            showAutoHiddenHud(style: .error, text: Localized.TOAST_RECAPTCHA_TIMED_OUT)
            guard let weakSelf = self else {
                return
            }
            weakSelf.completion?(.timedOut)
            weakSelf.clean()
        })
    }
    
    func cancel() {
        completion?(.cancel)
        clean()
    }
    
    func clean() {
        timer?.invalidate()
        timer = nil
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: messageHandlerName)
        webView?.removeFromSuperview()
        webView = nil
        reCaptchaViewController = nil
        requestingViewController = nil
        completion = nil
    }
    
    private func challengeChanged() {
        guard let requestingViewController = requestingViewController, let webView = webView else {
            clean()
            return
        }
        guard requestingViewController.presentedViewController == nil else {
            return
        }
        webView.removeFromSuperview()
        let reCaptchaViewController = ReCaptchaViewController.instance(webView: webView)
        requestingViewController.present(reCaptchaViewController, animated: true, completion: nil)
    }
    
}

extension ReCaptchaManager: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let msg = Message(messageBody: message.body) else {
            let body = String(describing: message.body)
            Reporter.report(error: MixinError.unrecognizedReCaptchaMessage(body))
            return
        }
        switch msg {
        case .didLoad:
            timer?.invalidate()
            timer = nil
            webView?.evaluateJavaScript(executeReCaptchaJS, completionHandler: { [weak self] (_, error) in
                guard let error = error else {
                    return
                }
                self?.completion?(.failed(error))
                self?.clean()
            })
        case .challengeChange:
            challengeChanged()
        case .token(let token):
            if let vc = requestingViewController?.presentedViewController {
                vc.dismiss(animated: true, completion: {
                    self.completion?(.success(token))
                    self.clean()
                })
            } else {
                completion?(.success(token))
                clean()
            }
        }
    }
    
}

extension ReCaptchaManager {
    
    typealias CompletionCallback = (Result) -> Void
    
    enum Result {
        case success(String)
        case cancel
        case timedOut
        case failed(Error)
    }
    
    enum Replacement {
        static let apiKey = "${api_key}"
        static let scriptURL = "${script_url}"
    }
    
    enum Message {
        case challengeChange
        case didLoad
        case token(String)
        
        init?(messageBody: Any) {
            guard let body = messageBody as? [String: String] else {
                return nil
            }
            if let message = body["message"] {
                if message == "did_load" {
                    self = .didLoad
                } else if message == "challenge_change" {
                    self = .challengeChange
                } else {
                    return nil
                }
            } else if let token = body["token"] {
                self = .token(token)
            } else {
                return nil
            }
        }
    }
    
}
