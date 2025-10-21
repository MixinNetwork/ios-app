import UIKit
import WebKit
import MixinServices

final class Captcha: NSObject {
    
    protocol Reporting {
        var reportingContent: (event: Reporter.Event, type: String) { get }
    }
    
    private let messageHandlerName = "mixin_messenger_captcha"
    private let baseURL = URL(string: "https://api.mixin.one/")!
    
    private weak var viewController: UIViewController?
    
    private lazy var scriptMessageProxy = ScriptMessageProxy(target: self)
    
    private var webView: WKWebView?
    private var completion: CompletionCallback?
    private var initGTCaptchaAfterNavigationFinished = false
    
    private var opaquePointer: UnsafeMutableRawPointer {
        Unmanaged<Captcha>.passUnretained(self).toOpaque()
    }
    
    init(viewController: UIViewController) {
        self.viewController = viewController
        super.init()
        Logger.login.debug(category: "Captcha", message: "Init \(opaquePointer)")
    }
    
    deinit {
        clean()
        Logger.login.debug(category: "Captcha", message: "Deinit \(opaquePointer)")
    }
    
    func validate(
        errorDescription: String?,
        completion: @escaping CompletionCallback
    ) {
        guard let view = viewController?.view else {
            return
        }
        if let content = (viewController as? Reporting)?.reportingContent {
            reporter.report(event: content.event, tags: ["type": content.type])
        }
        self.completion = completion
        if webView == nil {
            let config = WKWebViewConfiguration()
            config.preferences.isFraudulentWebsiteWarningEnabled = false
            config.userContentController.add(scriptMessageProxy, name: messageHandlerName)
            let webView = WKWebView(frame: view.bounds, configuration: config)
            webView.frame.origin.y = view.bounds.height
            webView.navigationDelegate = self
#if DEBUG
            if #available(iOS 16.4, *) {
                webView.isInspectable = true
            }
#endif
            view.addSubview(webView)
            self.webView = webView
        }
        let hint = errorDescription ?? ""
        if hint.hasPrefix("hCaptcha") {
            loadPage(key: MixinKeys.hCaptcha, scriptTag: ScriptTag.hCaptcha)
        } else if hint.hasPrefix("GeeTest") {
            initGTCaptchaAfterNavigationFinished = true
            loadPage(key: MixinKeys.geeTest, scriptTag: ScriptTag.gtCaptcha)
        } else {
            loadPage(key: MixinKeys.reCaptcha, scriptTag: ScriptTag.reCaptcha)
        }
    }
    
    func cancel() {
        completion?(.cancel)
        clean()
    }
    
    private func clean() {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: messageHandlerName)
        webView?.removeFromSuperview()
        webView = nil
        completion = nil
    }
    
}

extension Captcha: UIAdaptivePresentationControllerDelegate {
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        cancel()
    }
    
}

extension Captcha: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard initGTCaptchaAfterNavigationFinished else {
            return
        }
        initGTCaptchaAfterNavigationFinished = false
        webView.evaluateJavaScript("initGTCaptcha();")
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
            webView?.evaluateJavaScript("gReCaptchaExecute();")
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
            Logger.login.error(category: "Captcha", message: "hCaptcha validation timeout")
            viewController?.dismiss(animated: true, completion: nil)
            showAutoHiddenHud(style: .error, text: R.string.localizable.validation_timed_out())
            completion?(.timedOut)
            clean()
        case let .reCaptchaToken(token):
            report(token: .reCaptcha(token))
        case let .hCaptchaToken(token):
            report(token: .hCaptcha(token))
        case let .gtCaptchaResult(result):
            report(token: .gtCaptcha(result))
        case .gtCaptchaClose:
            if let viewController {
                viewController.dismiss(animated: true) {
                    self.cancel()
                }
            } else {
                cancel()
            }
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
        static let scriptTag = "${script_tag}"
    }
    
    private enum ScriptTag {
        
        static let reCaptcha = #"<script src="https://www.recaptcha.net/recaptcha/api.js?onload=onReCaptchaLoad&render=explicit" async defer>"#
        static let hCaptcha = #"<script src="https://hcaptcha.com/1/api.js?onload=onHCaptchaLoad&render=explicit" async defer>"#
        
        static var gtCaptcha: String {
            let url = R.file.gt4Js.url()!
            let content = try! String(contentsOf: url)
            return "<script>\n" + content
        }
        
    }
    
    private enum Message {
        
        case challengeChange
        case reCaptchaDidLoad
        case hCaptchaFailed
        case reCaptchaToken(String)
        case hCaptchaToken(String)
        case gtCaptchaResult([String: String])
        case gtCaptchaClose
        
        init?(messageBody: Any) {
            if let body = messageBody as? [String: Any],
               let result = body["gtcaptcha_result"] as? [String: String]
            {
                self = .gtCaptchaResult(result)
            } else if let body = messageBody as? [String: String] {
                if let message = body["message"] {
                    switch message {
                    case "recaptcha_did_load":
                        self = .reCaptchaDidLoad
                    case "challenge_change":
                        self = .challengeChange
                    case "hcaptcha_failed":
                        self = .hCaptchaFailed
                    case "gt_close":
                        self = .gtCaptchaClose
                    default:
                        return nil
                    }
                } else if let token = body["recaptcha_token"] {
                    self = .reCaptchaToken(token)
                } else if let token = body["hcaptcha_token"] {
                    self = .hCaptchaToken(token)
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
        
    }
    
    private func loadPage(key: String?, scriptTag: String) {
        guard let webView = webView else {
            return
        }
        let htmlFileURL = R.file.captchaHtml.url()!
        let htmlString = try! String(contentsOf: htmlFileURL)
        guard let key else {
            assertionFailure("Failed to load captcha.html. Probably due to missing of Mixin-Keys.plist")
            return
        }
        let keyReplacedHTMLString = htmlString
            .replacingOccurrences(of: Replacement.apiKey, with: key)
            .replacingOccurrences(of: Replacement.scriptTag, with: scriptTag)
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
