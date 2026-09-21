import UIKit
import MixinServices

final class CustomerServiceViewController: PopupTitledWebViewController {
    
    private let presentLoginLogsOnLongPressingTitle: Bool
    private let reportingTags: [String: String]?
    
    init(
        presentLoginLogsOnLongPressingTitle: Bool = false,
        reportingTags: [String: String]?,
    ) {
        self.presentLoginLogsOnLongPressingTitle = presentLoginLogsOnLongPressingTitle
        self.reportingTags = reportingTags
        super.init(
            title: R.string.localizable.mixin_support(),
            subtitle: R.string.localizable.ask_me_anything(),
            url: .customerService
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
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
