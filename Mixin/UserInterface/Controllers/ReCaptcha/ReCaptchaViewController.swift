import UIKit
import WebKit

class ReCaptchaViewController: UIViewController {
    
    @IBOutlet weak var webViewContainerView: UIView!
    
    var webViewToLoad: WKWebView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let webView = webViewToLoad {
            webView.frame = webViewContainerView.bounds
            webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            webViewContainerView.addSubview(webView)
            webViewToLoad = nil
        }
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        dismiss(animated: true) {
            ReCaptchaManager.shared.cancel()
        }
    }
    
    class func instance(webView: WKWebView) -> ReCaptchaViewController {
        let vc = UIStoryboard(name: "ReCaptcha", bundle: .main).instantiateInitialViewController() as! ReCaptchaViewController
        vc.webViewToLoad = webView
        return vc
    }
    
}

extension ReCaptchaViewController: UINavigationBarDelegate {
    
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
    
}
