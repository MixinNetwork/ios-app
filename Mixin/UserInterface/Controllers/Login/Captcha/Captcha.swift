import UIKit
import WebKit
import MixinServices

final class Captcha: NSObject {
    
    private let messageHandlerName = "captcha"
    private let executeReCaptchaJS = "gReCaptchaExecute();"
    private let baseURL = URL(string: "https://api.mixin.one/")!
    private let timeoutInterval: TimeInterval = 10
    
    private weak var viewController: UIViewController?
    
    private lazy var scriptMessageProxy = ScriptMessageProxy(target: self)
    
    private var webView: WKWebView?
    private var completion: CompletionCallback?
    private var timer: Timer?
    
    private var opaquePointer: UnsafeMutableRawPointer {
        Unmanaged<Captcha>.passUnretained(self).toOpaque()
    }
    
    init(viewController: UIViewController) {
        self.viewController = viewController
        super.init()
        Logger.general.debug(category: "Captcha", message: "Init \(opaquePointer)")
    }
    
    deinit {
        clean()
        Logger.general.debug(category: "Captcha", message: "Deinit \(opaquePointer)")
    }
    
    func validate(completion: @escaping CompletionCallback) {
        guard let view = viewController?.view else {
            return
        }
        switch viewController {
        case let viewController as SignInWithMobileNumberViewController:
            reporter.report(event: .loginRecaptcha, method: "phone_number")
        case let viewController as SignUpWithMobileNumberViewController:
            reporter.report(event: .signUpRecaptcha, method: "phone_number")
        case let viewController as PhoneNumberLoginVerificationCodeViewController:
            reporter.report(event: .loginRecaptcha, method: "phone_number")
        case let viewController as RecoveryContactLoginVerificationCodeViewController:
            reporter.report(event: .loginRecaptcha, method: "recovery_contact")
        case let viewController as LoginWithMnemonicViewController:
            switch viewController.action {
            case .signUp:
                reporter.report(event: .signUpRecaptcha, method: "mnemonic")
            case .signIn:
                reporter.report(event: .loginRecaptcha, method: "mnemonic")
            }
        default:
            break
        }
        if webView == nil {
            let config = WKWebViewConfiguration()
            config.preferences.isFraudulentWebsiteWarningEnabled = false
            config.userContentController.add(scriptMessageProxy, name: messageHandlerName)
            let webView = WKWebView(frame: view.bounds, configuration: config)
            webView.frame.origin.y = view.bounds.height
            view.addSubview(webView)
            self.webView = webView
        }
        self.completion = completion
        validateWithReCaptcha()
    }
    
    func cancel() {
        completion?(.cancel)
        clean()
    }
    
    private func clean() {
        timer?.invalidate()
        timer = nil
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: messageHandlerName)
        webView?.removeFromSuperview()
        webView = nil
        completion = nil
    }
    
}

extension Captcha: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let message = Message(messageBody: message.body) else {
            let body = String(describing: message.body)
            reporter.report(error: MixinError.unrecognizedCaptchaMessage(body))
            return
        }
        switch message {
        case .reCaptchaDidLoad:
            timer?.invalidate()
            timer = nil
            webView?.evaluateJavaScript(executeReCaptchaJS) { [weak self] (_, error) in
                if error != nil {
                    self?.validateWithHCaptcha()
                }
            }
        case .challengeChange:
            guard let viewController, let webView = webView else {
                clean()
                return
            }
            guard viewController.presentedViewController == nil else {
                return
            }
            webView.removeFromSuperview()
            let captchaViewController = CaptchaViewController(manager: self)
            captchaViewController.load(webView: webView)
            captchaViewController.presentationController?.delegate = self
            viewController.present(captchaViewController, animated: true, completion: nil)
        case .hCaptchaFailed:
            viewController?.dismiss(animated: true, completion: nil)
            showAutoHiddenHud(style: .error, text: R.string.localizable.validation_timed_out())
            completion?(.timedOut)
            clean()
        case let .reCaptchaToken(token):
            report(token: .reCaptcha(token))
        case let .hCaptchaToken(token):
            report(token: .hCaptcha(token))
        }
    }
    
}

extension Captcha: UIAdaptivePresentationControllerDelegate {
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        cancel()
    }
    
}

extension Captcha {
    
    private func validateWithReCaptcha() {
        guard let htmlFileURL = R.file.captchaHtml.url(),
              let htmlString = try? String(contentsOf: htmlFileURL),
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
        WKWebsiteDataStore.default().removeAuthenticationRelatedData()
        
        guard let htmlFileURL = R.file.captchaHtml.url(),
              let htmlString = try? String(contentsOf: htmlFileURL),
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
        if let viewController,
           let presentedViewController = viewController.presentedViewController,
           presentedViewController is CaptchaViewController
        {
            viewController.dismiss(animated: true) {
                self.completion?(.success(token))
                self.clean()
            }
        } else {
            completion?(.success(token))
            clean()
        }
    }
    
}

extension Captcha {
    
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
