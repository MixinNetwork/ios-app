import UIKit
import WebKit

final class CustomerServiceViewController: UIViewController {
    
    @IBOutlet weak var titleView: PopupTitleView!
    @IBOutlet weak var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleView.titleLabel.font = .scaledFont(ofSize: 16, weight: .medium)
        titleView.titleLabel.text = R.string.localizable.mixin_support()
        titleView.subtitleLabel.text = R.string.localizable.ask_me_anything()
        titleView.closeButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        let request = URLRequest(url: .customerService)
        webView.load(request)
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
}
