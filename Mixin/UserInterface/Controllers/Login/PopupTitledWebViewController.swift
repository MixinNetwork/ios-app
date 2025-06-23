import UIKit
import WebKit

class PopupTitledWebViewController: UIViewController {
    
    @IBOutlet weak var titleView: PopupTitleView!
    
    private let popupTitle: String
    private let popupSubtitle: String?
    private let configuration: WKWebViewConfiguration
    private let request: URLRequest
    
    private weak var webView: WKWebView!
    
    init(
        title: String,
        subtitle: String?,
        configuration: WKWebViewConfiguration,
        request: URLRequest
    ) {
        self.popupTitle = title
        self.popupSubtitle = subtitle
        self.configuration = configuration
        self.request = request
        let nib = R.nib.popupTitledWebView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    init(title: String, subtitle: String?, url: URL) {
        self.popupTitle = title
        self.popupSubtitle = subtitle
        self.configuration = WKWebViewConfiguration()
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
        webView.uiDelegate = self
        webView.load(request)
        self.webView = webView
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
}

extension PopupTitledWebViewController: WKUIDelegate {
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let popup = PopupTitledWebViewController(
            title: popupTitle,
            subtitle: popupSubtitle,
            configuration: configuration,
            request: navigationAction.request
        )
        present(popup, animated: true)
        return nil
    }
    
}
