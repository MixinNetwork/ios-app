import UIKit
import WebKit
import MixinServices

class CaptchaManager: NSObject {
    
    static let shared = CaptchaManager()
    
    private let messageHandlerName = "captcha"
    private let executeReCaptchaJS = "gReCaptchaExecute();"
    private let baseURL = URL(string: "https://api.mixin.one/")!
    private let timeoutInterval: TimeInterval = 10
    
    private weak var requestingViewController: UIViewController?
    
    private var webView: WKWebView?
    private var completion: CompletionCallback?
    private var timer: Timer?
    
    func validate(on viewController: UIViewController, completion: @escaping CompletionCallback) {
        let window = AppDelegate.current.mainWindow
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: messageHandlerName)
        let webView = WKWebView(frame: window.bounds, configuration: config)
        webView.frame.origin.y = window.bounds.height
        window.addSubview(webView)
        self.webView = webView
        self.requestingViewController = viewController
        self.completion = completion
        validateWithReCaptcha()
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
        requestingViewController = nil
        completion = nil
    }
    
}

extension CaptchaManager: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let msg = Message(messageBody: message.body) else {
            let body = String(describing: message.body)
            reporter.report(error: MixinError.unrecognizedCaptchaMessage(body))
            return
        }
        switch msg {
        case .reCaptchaDidLoad:
            timer?.invalidate()
            timer = nil
            webView?.evaluateJavaScript(executeReCaptchaJS, completionHandler: { [weak self] (_, error) in
                if error != nil {
                    self?.validateWithHCaptcha()
                }
            })
        case .challengeChange:
            guard let requestingViewController = requestingViewController, let webView = webView else {
                clean()
                return
            }
            guard requestingViewController.presentedViewController == nil else {
                return
            }
            webView.removeFromSuperview()
            let captchaViewController = CaptchaViewController()
            captchaViewController.load(webView: webView)
            requestingViewController.present(captchaViewController, animated: true, completion: nil)
        case .hCaptchaFailed:
            requestingViewController?.dismiss(animated: true, completion: nil)
            showAutoHiddenHud(style: .error, text: R.string.localizable.toast_captcha_timeout())
            completion?(.timedOut)
            clean()
        case let .reCaptchaToken(token):
            report(token: .reCaptcha(token))
        case let .hCaptchaToken(token):
            report(token: .hCaptcha(token))
        }
    }
    
}

extension CaptchaManager {
    
    private func validateWithReCaptcha() {
        guard let htmlFilePath = R.file.captchaHtml.path(),
              let htmlString = try? String(contentsOfFile: htmlFilePath),
              let reCaptchaKey = MixinKeys.reCaptcha
        else {
            assertionFailure("Failed to load captcha.html. Probably due to missing of Mixin-Keys.plist")
            return
        }
        
        let keyReplacedHTMLString = htmlString
            .replacingOccurrences(of: Replacement.apiKey, with: reCaptchaKey)
            .replacingOccurrences(of: Replacement.scriptURL, with: ScriptURL.reCaptcha)
        webView?.loadHTMLString(keyReplacedHTMLString, baseURL: baseURL)
        timer = Timer.scheduledTimer(withTimeInterval: timeoutInterval, repeats: false) { [weak self] (_) in
            guard let self = self else {
                return
            }
            self.timer = nil
            self.validateWithHCaptcha()
        }
    }
    
    private func validateWithHCaptcha() {
        guard let webView = webView else {
            return
        }
        webView.load(URLRequest(url: .blank))
        WKWebsiteDataStore.default().removeAllCookiesAndLocalStorage()
        
        guard let htmlFilePath = R.file.captchaHtml.path(),
              let htmlString = try? String(contentsOfFile: htmlFilePath),
              let hCaptchaKey = MixinKeys.hCaptcha
        else {
            assertionFailure("Failed to load captcha.html. Probably due to missing of Mixin-Keys.plist")
            return
        }
        
        let keyReplacedHTMLString = htmlString
            .replacingOccurrences(of: Replacement.apiKey, with: hCaptchaKey)
            .replacingOccurrences(of: Replacement.scriptURL, with: ScriptURL.hCaptcha)
        webView.loadHTMLString(keyReplacedHTMLString, baseURL: baseURL)
    }
    
    private func report(token: CaptchaToken) {
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

extension CaptchaManager {
    
    typealias CompletionCallback = (Result) -> Void
    
    enum Result {
        case success(CaptchaToken)
        case cancel
        case timedOut
    }
    
    private enum Replacement {
        static let apiKey = "${api_key}"
        static let scriptURL = "${script_url}"
    }
    
    private enum ScriptURL {
        static let reCaptcha = "https://www.recaptcha.net/recaptcha/api.js?onload=onReCaptchaLoad&render=explicit"
        static let hCaptcha = "https://hcaptcha.com/1/api.js?onload=onHCaptchaLoad&render=explicit"
    }
    
    private enum Message {
        case challengeChange
        case reCaptchaDidLoad
        case hCaptchaFailed
        case reCaptchaToken(String)
        case hCaptchaToken(String)
        
        init?(messageBody: Any) {
            guard let body = messageBody as? [String: String] else {
                return nil
            }
            if let message = body["message"] {
                if message == "recaptcha_did_load" {
                    self = .reCaptchaDidLoad
                } else if message == "challenge_change" {
                    self = .challengeChange
                } else if message == "hcaptcha_failed" {
                    self = .hCaptchaFailed
                } else {
                    return nil
                }
            } else if let token = body["recaptcha_token"] {
                self = .reCaptchaToken(token)
            } else if let token = body["hcaptcha_token"] {
                self = .hCaptchaToken(token)
            } else {
                return nil
            }
        }
    }
    
}
