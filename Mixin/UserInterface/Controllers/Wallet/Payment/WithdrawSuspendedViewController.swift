import UIKit
import MixinServices

protocol WithdrawSuspendedViewControllerDelegate: AnyObject {
    func withdrawSuspendedViewControllerDidRealize(_ controller: WithdrawSuspendedViewController)
    func withdrawSuspendedViewControllerWantsContactSupport(_ controller: WithdrawSuspendedViewController)
}

final class WithdrawSuspendedViewController: UIViewController {

    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tokenIconView: AssetIconView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var realizeButton: RoundedButton!
    
    weak var delegate: WithdrawSuspendedViewControllerDelegate?
    
    private let token: TokenItem
    
    init(token: TokenItem) {
        self.token = token
        let nib = R.nib.withdrawSuspendedView
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = PopupPresentationManager.shared
        modalPresentationStyle = .custom
        preferredContentSize.height = 433
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        contentStackView.setCustomSpacing(23, after: tokenIconView)
        contentStackView.setCustomSpacing(12, after: realizeButton)
        view.layer.cornerRadius = 13
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        titleLabel.text = R.string.localizable.withdrawal_suspended(token.symbol)
        tokenIconView.setIcon(token: token)
        descriptionLabel.text = R.string.localizable.withdrawal_suspended_description(token.symbol)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(presentationViewControllerDidDismissPresentedViewController(_:)),
                                               name: PopupPresentationController.didDismissPresentedViewControllerNotification,
                                               object: nil)
    }
    
    @IBAction func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true) {
            self.delegate?.withdrawSuspendedViewControllerDidRealize(self)
        }
    }
    
    @IBAction func contactSupport(_ sender: Any) {
        guard let presentingViewController else {
            return
        }
        presentingViewController.dismiss(animated: true, completion: {
            self.delegate?.withdrawSuspendedViewControllerWantsContactSupport(self)
        })
    }
    
    @objc private func presentationViewControllerDidDismissPresentedViewController(_ notification: Notification) {
        guard let controller = notification.object as? PopupPresentationController else {
            return
        }
        guard controller.presentedViewController == self else {
            return
        }
        self.delegate?.withdrawSuspendedViewControllerDidRealize(self)
    }
    
}
