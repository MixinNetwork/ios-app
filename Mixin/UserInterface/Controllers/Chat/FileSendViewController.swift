import UIKit
import WebKit

class FileSendViewController: UIViewController, MixinNavigationAnimating {

    private var documentUrl: URL!
    private var webView : WKWebView!
    
    private weak var conversationInputViewController: ConversationInputViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        container?.leftButton.tintColor = R.color.icon_tint()
        container?.leftButton.setImage(R.image.ic_title_close(), for: .normal)
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = .all
        webView = WKWebView(frame: self.view.frame, configuration: config)
        self.view.addSubview(webView)
        webView.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
        webView.loadFileURL(documentUrl, allowingReadAccessTo: documentUrl)
    }

    class func instance(documentUrl: URL, conversationInputViewController: ConversationInputViewController) -> UIViewController {
        let vc = FileSendViewController()
        vc.documentUrl = documentUrl
        vc.conversationInputViewController = conversationInputViewController
        return ContainerViewController.instance(viewController: vc, title: documentUrl.lastPathComponent.substring(endChar:  "."))
    }

}

extension FileSendViewController: ContainerViewControllerDelegate {

    func barRightButtonTappedAction() {
        guard let url = documentUrl else {
            return
        }
        conversationInputViewController?.sendFile(url: url)
        navigationController?.popViewController(animated: true)
    }

    func imageBarRightButton() -> UIImage? {
        return R.image.conversation.ic_send()
    }

}
