import UIKit
import MixinServices

protocol WalletHintViewControllerDelegate: AnyObject {
    func walletHintViewControllerDidRealize(_ controller: WalletHintViewController)
    func walletHintViewControllerWantsContactSupport(_ controller: WalletHintViewController)
}

final class WalletHintViewController: UIViewController {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tokenIconView: BadgeIconView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var realizeButton: RoundedButton!
    @IBOutlet weak var contactSupportButton: UIButton!
    
    @IBOutlet weak var contentStackTopConstraint: NSLayoutConstraint!
    
    weak var delegate: WalletHintViewControllerDelegate?
    
    private let token: TokenItem
    
    init(token: TokenItem) {
        self.token = token
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
        contentStackView.setCustomSpacing(23, after: tokenIconView)
        contentStackView.setCustomSpacing(12, after: realizeButton)
        view.layer.cornerRadius = 13
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        tokenIconView.setIcon(token: token)
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
    
    func setTitle(_ title: String, description: String) {
        loadViewIfNeeded()
        titleLabel.text = title
        descriptionLabel.text = description
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
