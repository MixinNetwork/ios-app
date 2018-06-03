import UIKit
import WebKit
import SwiftMessages

class ReCaptchaManager: NSObject {
    
    static let shared = ReCaptchaManager()
    
    private static let timeOutInterval = DispatchTimeInterval.seconds(10)
    
    var webView: WKWebView?
    var reCaptchaViewController: ReCaptchaViewController?
    
    private let messageHandlerName = "recaptcha"
    private let executeReCaptchaJS = "gReCaptchaExecute();"
    private let scriptURL = "https://www.recaptcha.net/recaptcha/api.js"
    private let queue = DispatchQueue(label: "one.mixin.messenger.queue.recaptcha")
    private var semaphore = DispatchSemaphore(value: 0)
    
    private lazy var htmlFilePath = Bundle.main.path(forResource: "recaptcha", ofType: ExtensionName.html.rawValue)
    private weak var requestingViewController: UIViewController?
    private var completion: CompletionCallback?
    
    func validate(onViewController viewController: UIViewController, completion: @escaping CompletionCallback) {
        guard let htmlFilePath = htmlFilePath, let htmlString = try? String(contentsOfFile: htmlFilePath), let key = MixinKeys.reCaptcha else {
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
        webView.loadHTMLString(keyReplacedHTMLString, baseURL: BaseAPI.rootURL)
        self.webView = webView
        queue.async { [weak viewController] in
            let result = self.semaphore.wait(timeout: .now() + ReCaptchaManager.timeOutInterval)
            if result == .timedOut {
                DispatchQueue.main.async {
                    if viewController != nil {
                        SwiftMessages.showToast(message: Localized.TOAST_RECAPTCHA_TIMED_OUT, backgroundColor: .hintRed)
                        completion(.timedOut)
                    }
                    self.clean()
                }
            } else {
                if let viewController = viewController {
                    self.requestingViewController = viewController
                    self.completion = completion
                    self.executeRecaptcha()
                }
            }
        }
    }
    
    func cancel() {
        completion?(.cancel)
        clean()
    }
    
    func clean() {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: messageHandlerName)
        webView?.removeFromSuperview()
        webView = nil
        reCaptchaViewController = nil
        requestingViewController = nil
        completion = nil
        semaphore.signal()
        semaphore = DispatchSemaphore(value: 0)
    }
    
    private func executeRecaptcha() {
        webView?.evaluateJavaScript(executeReCaptchaJS, completionHandler: { [weak self] (_, error) in
            if let error = error {
                self?.completion?(.failed(error))
                self?.clean()
            }
        })
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
            UIApplication.trackError("ReCaptchaManager", action: "Unrecognized Message", userInfo: ["body": message.body])
            return
        }
        switch msg {
        case .didLoad:
            semaphore.signal()
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
