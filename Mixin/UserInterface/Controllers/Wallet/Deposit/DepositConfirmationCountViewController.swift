import UIKit

final class DepositConfirmationCountViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var closeButton: UIButton!
    
    private let count: Int
    
    init(count: Int) {
        self.count = count
        let nib = R.nib.depositConfirmationCountView
        super.init(nibName: nib.name, bundle: nib.bundle)
        modalPresentationStyle = .custom
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.cornerRadius = 13
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 18, weight: .semibold),
            adjustForContentSize: true
        )
        titleLabel.text = R.string.localizable.block_confirmations()
        descriptionLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        descriptionLabel.text = R.string.localizable.deposit_confirmation(count)
        if var config = closeButton.configuration {
            let attributes: AttributeContainer = {
                var container = AttributeContainer()
                container.font = UIFontMetrics.default.scaledFont(
                    for: .systemFont(ofSize: 16, weight: .medium)
                )
                container.foregroundColor = .white
                return container
            }()
            config.attributedTitle = AttributedString(
                R.string.localizable.got_it(),
                attributes: attributes
            )
            closeButton.configuration = config
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePreferredContentSizeHeight()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePreferredContentSizeHeight()
    }
    
    @IBAction func close() {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    private func updatePreferredContentSizeHeight() {
        guard let superview = view.superview else {
            return
        }
        view.layoutIfNeeded()
        let sizeToFit = CGSize(
            width: superview.bounds.width,
            height: UIView.layoutFittingExpandedSize.height
        )
        preferredContentSize.height = view.systemLayoutSizeFitting(
            sizeToFit,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
    }
    
}
