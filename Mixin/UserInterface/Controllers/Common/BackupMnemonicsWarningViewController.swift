import UIKit
import MixinServices

final class BackupMnemonicsWarningViewController: UIViewController {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var backupButton: StyledButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    private let cancelTitle: String
    
    private weak var exportNavigationController: UINavigationController?
    
    var onCancel: (() -> Void)?
    
    init(navigationController: UINavigationController?, cancelTitle: String) {
        self.exportNavigationController = navigationController
        self.cancelTitle = cancelTitle
        let nib = R.nib.backupMnemonicsWarningView
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.cornerRadius = 13
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true
        contentStackView.setCustomSpacing(16, after: titleLabel)
        contentStackView.setCustomSpacing(40, after: descriptionLabel)
        contentStackView.setCustomSpacing(14, after: backupButton)
        titleLabel.text = R.string.localizable.backup_mnemonic_phrase()
        descriptionLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        descriptionLabel.text = R.string.localizable.backup_mnemonic_phrase_warning(myIdentityNumber)
        backupButton.setTitle(R.string.localizable.backup_now(), for: .normal)
        backupButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        backupButton.style = .filled
        backupButton.applyDefaultContentInsets()
        cancelButton.setTitle(cancelTitle, for: .normal)
        cancelButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePreferredContentSizeHeight()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePreferredContentSizeHeight()
    }
    
    @IBAction func backup(_ sender: Any) {
        presentingViewController?.dismiss(animated: true) { [exportNavigationController] in
            let introduction = ExportMnemonicPhrasesIntroductionViewController.contained()
            exportNavigationController?.pushViewController(introduction, animated: true)
        }
    }
    
    @IBAction func cancelBackup(_ sender: Any) {
        presentingViewController?.dismiss(animated: true) { [onCancel] in
            onCancel?()
        }
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
