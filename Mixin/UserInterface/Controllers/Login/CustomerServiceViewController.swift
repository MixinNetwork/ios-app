import UIKit
import WebKit
import MixinServices

final class CustomerServiceViewController: PopupTitledWebViewController {
    
    private let presentLoginLogsOnLongPressingTitle: Bool
    private let reportingTags: [String: String]?
    private let context: String
    
    private lazy var messageHandler = ScriptMessageProxy(target: self)
    
    init(
        presentLoginLogsOnLongPressingTitle: Bool = false,
        reportingTags: [String: String]?,
    ) {
        self.presentLoginLogsOnLongPressingTitle = presentLoginLogsOnLongPressingTitle
        self.reportingTags = reportingTags
        if let userID = LoginManager.shared.account?.userID {
            let conversationID = ConversationDAO.shared.makeConversationId(
                userId: userID,
                ownerUserId: BotUserID.teamMixin
            )
            self.context = #"{"conversation_id":"\#(conversationID)"}"#
        } else {
            self.context = "{}"
        }
        super.init(
            title: R.string.localizable.mixin_support(),
            subtitle: R.string.localizable.ask_me_anything(),
            url: .customerService
        )
        Logger.general.debug(category: "CustomerService", message: "Init \(ObjectIdentifier(self))")
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(
            forName: WebViewMessageHandler.Name.mixinContext.rawValue,
        )
        Logger.general.debug(category: "CustomerService", message: "Deinit \(ObjectIdentifier(self))")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let reportingTags {
            reporter.report(event: .customerServiceDialog, tags: reportingTags)
        }
        if presentLoginLogsOnLongPressingTitle {
            let presentLogRecognizer = UILongPressGestureRecognizer(
                target: self,
                action: #selector(presentLog(_:))
            )
            presentLogRecognizer.minimumPressDuration = 3
            titleView.addGestureRecognizer(presentLogRecognizer)
        }
    }
    
    override func replaceWebView(configuration: WKWebViewConfiguration) {
        webView?.configuration.userContentController.removeScriptMessageHandler(
            forName: WebViewMessageHandler.Name.mixinContext.rawValue,
        )
        configuration.userContentController.add(
            messageHandler,
            name: WebViewMessageHandler.Name.mixinContext.rawValue,
        )
        configuration.applicationNameForUserAgent = MixinWebContext.applicationNameForUserAgent
        super.replaceWebView(configuration: configuration)
        webView.uiDelegate = self
    }
    
    @objc private func presentLog(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            var topMost: UIViewController = self
            while let next = topMost.presentedViewController, !next.isBeingDismissed {
                topMost = next
            }
            let log = LoginLogViewController()
            topMost.present(log, animated: true)
        default:
            break
        }
    }
    
}

extension CustomerServiceViewController: WKUIDelegate {
    
    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        if prompt == WebViewMessageHandler.Name.mixinContext.rawValue + ".getContext()" {
            completionHandler(context)
        } else {
            completionHandler("")
        }
    }
    
}

extension CustomerServiceViewController: WKScriptMessageHandler {
    
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage,
    ) {
        // Required by ScriptMessageProxy. Not needed currently
    }
    
}
