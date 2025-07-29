import UIKit
import MixinServices

final class UncontrolledWalletWarningViewController: UIViewController {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var watchImageView: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var confirmButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    var onConfirm: (() -> Void)?
    
    private let wallet: Web3Wallet
    
    init(wallet: Web3Wallet) {
        self.wallet = wallet
        let nib = R.nib.uncontrolledWalletWarningView
        super.init(nibName: nib.name, bundle: nib.bundle)
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.cornerRadius = 13
        nameLabel.text = wallet.name
        switch wallet.category.knownCase {
        case .watchAddress:
            watchImageView.isHidden = false
            descriptionLabel.text = R.string.localizable.transfer_to_watch_wallet_warning()
        default:
            watchImageView.isHidden = true
            descriptionLabel.text = R.string.localizable.transfer_to_no_key_wallet_warning()
        }
        confirmButton.configuration?.attributedTitle = AttributedString(
            R.string.localizable.confirm(),
            attributes: AttributeContainer([
                .font: UIFontMetrics.default.scaledFont(
                    for: .systemFont(ofSize: 16, weight: .medium)
                )
            ])
        )
        cancelButton.configuration?.attributedTitle = AttributedString(
            R.string.localizable.cancel(),
            attributes: AttributeContainer([
                .font: UIFontMetrics.default.scaledFont(
                    for: .systemFont(ofSize: 16, weight: .medium)
                )
            ])
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePreferredContentSizeHeight()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePreferredContentSizeHeight()
    }
    
    @IBAction func confirm(_ sender: Any) {
        presentingViewController?.dismiss(animated: true) { [onConfirm] in
            onConfirm?()
        }
    }
    
    @IBAction func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    private func updatePreferredContentSizeHeight() {
        view.layoutIfNeeded()
        let width = view.bounds.width
        let fittingSize = CGSize(width: width, height: UIView.layoutFittingExpandedSize.height)
        preferredContentSize.height = view.systemLayoutSizeFitting(fittingSize).height
    }
    
}
