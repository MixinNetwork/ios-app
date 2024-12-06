import UIKit
import WebKit

final class FileSendViewController: UIViewController, MixinNavigationAnimating {
    
    private var documentUrl: URL!
    private var webView : WKWebView!
    
    private weak var conversationInputViewController: ConversationInputViewController!
    
    class func instance(documentUrl: URL, conversationInputViewController: ConversationInputViewController) -> UIViewController {
        let vc = FileSendViewController()
        vc.documentUrl = documentUrl
        vc.conversationInputViewController = conversationInputViewController
        vc.title = documentUrl.lastPathComponent.substring(endChar:  ".")
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = .tintedIcon(
            image: R.image.ic_title_close(),
            target: self,
            action: #selector(close(_:))
        )
        navigationItem.rightBarButtonItem = .tintedIcon(
            image: R.image.conversation.ic_send(),
            target: self,
            action: #selector(send(_:))
        )
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = .all
        webView = WKWebView(frame: self.view.frame, configuration: config)
        self.view.addSubview(webView)
        webView.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
        webView.loadFileURL(documentUrl, allowingReadAccessTo: documentUrl)
    }
    
    @objc private func close(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func send(_ sender: Any) {
        guard let url = documentUrl else {
            return
        }
        conversationInputViewController?.sendFile(url: url)
        navigationController?.popViewController(animated: true)
    }
    
}
