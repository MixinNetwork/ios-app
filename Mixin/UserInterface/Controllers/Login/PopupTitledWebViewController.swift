import UIKit
import WebKit

class PopupTitledWebViewController: UIViewController {
    
    @IBOutlet weak var titleView: PopupTitleView!
    @IBOutlet weak var webView: WKWebView!
    
    private let popupTitle: String
    private let popupSubtitle: String
    private let url: URL
    
    init(title: String, subtitle: String, url: URL) {
        self.popupTitle = title
        self.popupSubtitle = subtitle
        self.url = url
        let nib = R.nib.popupTitledWebView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleView.titleLabel.font = .scaledFont(ofSize: 16, weight: .medium)
        titleView.titleLabel.text = popupTitle
        titleView.subtitleLabel.text = popupSubtitle
        titleView.closeButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
}
