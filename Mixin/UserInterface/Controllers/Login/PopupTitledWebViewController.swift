import UIKit
import WebKit

class PopupTitledWebViewController: UIViewController {
    
    @IBOutlet weak var titleView: PopupTitleView!
    
    weak var webView: WKWebView!
    
    private let popupTitle: String
    private let popupSubtitle: String?
    private let request: URLRequest
    
    init(title: String, subtitle: String?, url: URL) {
        self.popupTitle = title
        self.popupSubtitle = subtitle
        self.request = URLRequest(url: url)
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
        replaceWebView(configuration: WKWebViewConfiguration())
        webView.load(request)
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    func replaceWebView(configuration: WKWebViewConfiguration) {
        self.webView?.removeFromSuperview()
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        view.addSubview(webView)
        webView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(titleView.snp.bottom)
        }
#if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
#endif
        
        self.webView = webView
    }
    
}
