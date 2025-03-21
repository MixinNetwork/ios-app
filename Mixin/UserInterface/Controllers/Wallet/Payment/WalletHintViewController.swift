import UIKit
import MixinServices

protocol WalletHintViewControllerDelegate: AnyObject {
    func walletHintViewControllerDidRealize(_ controller: WalletHintViewController)
    func walletHintViewControllerWantsContactSupport(_ controller: WalletHintViewController)
}

final class WalletHintViewController: UIViewController {
    
    class UserRealizedDelegation: WalletHintViewControllerDelegate {
        
        var onRealize: (() -> Void)?
        
        func walletHintViewControllerDidRealize(_ controller: WalletHintViewController) {
            onRealize?()
        }
        
        func walletHintViewControllerWantsContactSupport(_ controller: WalletHintViewController) {
            
        }
        
    }
    
    enum Content {
        case addressUpdated(MixinTokenItem)
        case withdrawSuspended(MixinTokenItem)
        case waitingTransaction
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var realizeButton: RoundedButton!
    @IBOutlet weak var contactSupportButton: UIButton!
    
    @IBOutlet weak var contentStackTopConstraint: NSLayoutConstraint!
    
    weak var delegate: WalletHintViewControllerDelegate?
    
    private let content: Content
    
    init(content: Content) {
        self.content = content
        let nib = R.nib.walletHintView
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        switch content {
        case .addressUpdated(let token), .withdrawSuspended(let token):
            let iconView = BadgeIconView()
            iconView.badgeIconDiameter = 18
            iconView.badgeOutlineWidth = 2
            contentStackView.insertArrangedSubview(iconView, at: 1)
            iconView.snp.makeConstraints { make in
                make.width.height.equalTo(70)
            }
            iconView.setIcon(token: token)
            contentStackView.setCustomSpacing(23, after: iconView)
        case .waitingTransaction:
            let iconView = UIImageView(image: R.image.waiting_transaction())
            contentStackView.insertArrangedSubview(iconView, at: 0)
            iconView.snp.makeConstraints { make in
                make.width.height.equalTo(70)
            }
            contentStackView.setCustomSpacing(19, after: iconView)
        }
        switch content {
        case .addressUpdated(let token):
            titleLabel.text = R.string.localizable.depost_address_updated(token.symbol)
            descriptionLabel.text = R.string.localizable.depost_address_updated_description(token.symbol)
            contactSupportButton.alpha = 1
        case .withdrawSuspended(let token):
            titleLabel.text = R.string.localizable.withdrawal_suspended(token.symbol)
            descriptionLabel.text = R.string.localizable.withdrawal_suspended_description(token.symbol)
            contactSupportButton.alpha = 1
        case .waitingTransaction:
            titleLabel.text = R.string.localizable.waiting_transaction()
            descriptionLabel.text = R.string.localizable.waiting_transaction_description()
            contactSupportButton.alpha = 0
        }
        contentStackView.setCustomSpacing(12, after: realizeButton)
        view.layer.cornerRadius = 13
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(presentationViewControllerDidDismissPresentedViewController(_:)),
                                               name: BackgroundDismissablePopupPresentationController.didDismissPresentedViewControllerNotification,
                                               object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePreferredContentSizeHeight()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePreferredContentSizeHeight()
    }
    
    @IBAction func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true) {
            self.delegate?.walletHintViewControllerDidRealize(self)
        }
    }
    
    @IBAction func contactSupport(_ sender: Any) {
        guard let presentingViewController else {
            return
        }
        presentingViewController.dismiss(animated: true, completion: {
            self.delegate?.walletHintViewControllerWantsContactSupport(self)
        })
    }
    
    @objc private func presentationViewControllerDidDismissPresentedViewController(_ notification: Notification) {
        guard let controller = notification.object as? BackgroundDismissablePopupPresentationController else {
            return
        }
        guard controller.presentedViewController == self else {
            return
        }
        self.delegate?.walletHintViewControllerDidRealize(self)
    }
    
    private func updatePreferredContentSizeHeight() {
        view.layoutIfNeeded()
        let sizeToFit = CGSize(width: contentStackView.frame.width,
                               height: UIView.layoutFittingExpandedSize.height)
        preferredContentSize.height = contentStackTopConstraint.constant
            + contentStackView.systemLayoutSizeFitting(sizeToFit).height
            + 17
            + view.safeAreaInsets.bottom
    }
    
}
