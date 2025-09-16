import UIKit

final class CustomerServiceViewController: PopupTitledWebViewController {
    
    private let presentLoginLogsOnLongPressingTitle: Bool
    
    init(presentLoginLogsOnLongPressingTitle: Bool = false) {
        self.presentLoginLogsOnLongPressingTitle = presentLoginLogsOnLongPressingTitle
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
