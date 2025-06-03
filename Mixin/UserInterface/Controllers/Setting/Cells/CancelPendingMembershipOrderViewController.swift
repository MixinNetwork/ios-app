import UIKit
import MixinServices

final class CancelPendingMembershipOrderViewController: UIViewController {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var cancelOrderButton: RoundedButton!
    @IBOutlet weak var keepWaitingButton: UIButton!
    
    @IBOutlet weak var contentStackTopConstraint: NSLayoutConstraint!
    
    private let order: MembershipOrder
    
    init(order: MembershipOrder) {
        self.order = order
        let nib = R.nib.cancelPendingMembershipOrderView
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.cornerRadius = 16
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        contentStackView.setCustomSpacing(20, after: imageView)
        contentStackView.setCustomSpacing(40, after: descriptionLabel)
        imageView.image = switch order.transition {
        case .upgrade(let plan), .renew(let plan):
            switch plan {
            case .basic:
                R.image.membership_advance_large()
            case .standard:
                R.image.membership_elite_large()
            case .premium:
                UserBadgeIcon.prosperityImage
            }
        case .buyStars:
            R.image.mixin_star()
        case .none:
            nil
        }
        titleLabel.text = R.string.localizable.not_paid()
        descriptionLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        descriptionLabel.text = R.string.localizable.not_paid_description()
        cancelOrderButton.setTitle(R.string.localizable.cancel_waiting(), for: .normal)
        keepWaitingButton.setTitle(R.string.localizable.keep_waiting(), for: .normal)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePreferredContentSizeHeight()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePreferredContentSizeHeight()
    }
    
    @IBAction func cancelWaiting(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        let id = order.orderID.uuidString.lowercased()
        SafeAPI.cancelMembershipOrder(id: id) { result in
            switch result {
            case let .success(order):
                DispatchQueue.global().async {
                    MembershipOrderDAO.shared.save(orders: [order])
                }
                hud.set(style: .notification, text: R.string.localizable.canceled())
            case let .failure(error):
                hud.set(style: .error, text: error.localizedDescription)
            }
            hud.scheduleAutoHidden()
        }
    }
    
    @IBAction func keepWaiting(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    private func updatePreferredContentSizeHeight() {
        view.layoutIfNeeded()
        let sizeToFit = CGSize(
            width: contentStackView.frame.width,
            height: UIView.layoutFittingExpandedSize.height
        )
        preferredContentSize.height = contentStackTopConstraint.constant
        + contentStackView.systemLayoutSizeFitting(sizeToFit).height
        + 20
        + view.safeAreaInsets.bottom
    }
    
}
