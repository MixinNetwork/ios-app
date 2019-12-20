import UIKit
import WebKit

class FileSendViewController: UIViewController, MixinNavigationAnimating {

    private var documentUrl: URL!
    private var webView : WKWebView!
    private weak var dataSource: ConversationDataSource?

    override func viewDidLoad() {
        super.viewDidLoad()

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

    class func instance(documentUrl: URL, dataSource: ConversationDataSource?) -> UIViewController {
        let vc = FileSendViewController()
        vc.documentUrl = documentUrl
        vc.dataSource = dataSource
        return ContainerViewController.instance(viewController: vc, title: documentUrl.lastPathComponent.substring(endChar:  "."))
    }

}

extension FileSendViewController: ContainerViewControllerDelegate {

    func barRightButtonTappedAction() {
        guard let url = documentUrl else {
            return
        }
        dataSource?.sendMessage(type: .SIGNAL_DATA, value: url)
        navigationController?.popViewController(animated: true)
    }

    func imageBarRightButton() -> UIImage? {
        return R.image.ic_chat_send()
    }

}
