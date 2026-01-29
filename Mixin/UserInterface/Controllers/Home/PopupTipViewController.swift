import UIKit
import MixinServices

final class PopupTipViewController: UIViewController {
    
    @IBOutlet weak var imageBackgroundView: GradientView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var continueButton: StyledButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    private let tip: PopupTip
    private let presentationManager = PopupPresentationManager()
    
    init(tip: PopupTip) {
        self.tip = tip
        let nib = R.nib.popupTipView
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = presentationManager
        modalPresentationStyle = .custom
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 13
        imageBackgroundView.lightColors = [
            UIColor(displayP3RgbValue: 0xFFFFFF),
            UIColor(displayP3RgbValue: 0xF7F7F7),
        ]
        imageBackgroundView.darkColors = [
            UIColor(displayP3RgbValue: 0x2C3136),
            UIColor(displayP3RgbValue: 0x1C2029),
        ]
        switch tip {
        case .appUpdate:
            imageView.image = R.image.tips_update()
            titleLabel.text = R.string.localizable.new_update_available()
            descriptionLabel.text = R.string.localizable.new_update_available_desc()
            continueButton.setTitle(R.string.localizable.update_now(), for: .normal)
        case .backupMnemonics:
            imageView.image = R.image.tips_mnemonics()
            titleLabel.text = R.string.localizable.backup_mnemonic_phrase()
            descriptionLabel.text = R.string.localizable.backup_mnemonic_phrase_desc()
            continueButton.setTitle(R.string.localizable.backup_now(), for: .normal)
        case .notification:
            imageView.image = R.image.tips_notification()
            titleLabel.text = R.string.localizable.enable_push_notification()
            descriptionLabel.text = R.string.localizable.notification_content()
            continueButton.setTitle(R.string.localizable.enable_notifications(), for: .normal)
        case .recoveryContact:
            imageView.image = R.image.tips_recovery_contact()
            titleLabel.text = R.string.localizable.emergency_contact()
            descriptionLabel.text = R.string.localizable.setting_emergency_content()
            continueButton.setTitle(R.string.localizable.continue(), for: .normal)
        case .appRating:
            assertionFailure("No preview for app rating. Call `AppStore.requestReview(in:)` instead.")
        case .importPrivateKey:
            imageView.image = R.image.tips_import_private_key()
            titleLabel.text = R.string.localizable.import_private_key()
            descriptionLabel.text = R.string.localizable.import_secret_description(R.string.localizable.private_key())
            continueButton.setTitle(R.string.localizable.import_now(), for: .normal)
        case .importMnemonics:
            imageView.image = R.image.tips_import_mnemonics()
            titleLabel.text = R.string.localizable.import_mnemonic_phrase()
            descriptionLabel.text = R.string.localizable.import_secret_description(R.string.localizable.mnemonic_phrase())
            continueButton.setTitle(R.string.localizable.import_now(), for: .normal)
        }
        continueButton.style = .filled
        continueButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        continueButton.applyDefaultContentInsets()
        cancelButton.setTitle(R.string.localizable.not_now(), for: .normal)
        cancelButton.setTitleColor(R.color.theme(), for: .normal)
        cancelButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        cancelButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 0, bottom: 15, trailing: 0)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePreferredContentSizeHeight()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePreferredContentSizeHeight()
    }
    
    @IBAction func continueToNext(_ sender: Any) {
        switch tip {
        case .appUpdate:
            UIApplication.shared.open(.mixinMessenger, options: [:], completionHandler: nil)
            presentingViewController?.dismiss(animated: true)
        case .backupMnemonics:
            presentingViewController?.dismiss(animated: true) {
                let introduction = ExportMnemonicPhrasesIntroductionViewController()
                UIApplication.homeNavigationController?.pushViewController(introduction, animated: true)
            }
        case .notification:
            presentingViewController?.dismiss(animated: true)
            let center: UNUserNotificationCenter = .current()
            center.getNotificationSettings { settings in
                switch settings.authorizationStatus {
                case .notDetermined:
                    NotificationManager.shared.requestAuthorization()
                case .denied:
                    DispatchQueue.main.async(execute: UIApplication.shared.openNotificationSettings)
                case .authorized, .provisional, .ephemeral:
                    assertionFailure()
                @unknown default:
                    break
                }
            }
        case .recoveryContact:
            presentingViewController?.dismiss(animated: true) {
                let add = AddRecoveryContactViewController()
                UIApplication.homeNavigationController?.pushViewController(add, animated: true)
            }
        case .appRating:
            break
        case .importPrivateKey(let wallet):
            presentingViewController?.dismiss(animated: true) {
                let validation = AddWalletPINValidationViewController(action: .reimportPrivateKey(wallet))
                UIApplication.homeNavigationController?.pushViewController(validation, animated: true)
            }
        case .importMnemonics(let wallet):
            presentingViewController?.dismiss(animated: true) {
                let validation = AddWalletPINValidationViewController(action: .reimportMnemonics(wallet))
                UIApplication.homeNavigationController?.pushViewController(validation, animated: true)
            }
        }
    }
    
    @IBAction func cancel(_ sender: Any) {
        switch tip {
        case .appUpdate:
            AppGroupUserDefaults.appUpdateTipDismissalDate = Date()
        case .backupMnemonics:
            AppGroupUserDefaults.User.backupMnemonicsTipDismissalDate = Date()
        case .notification:
            AppGroupUserDefaults.notificationTipDismissalDate = Date()
        case .recoveryContact:
            AppGroupUserDefaults.User.recoveryContactTipDismissalDate = Date()
        case .appRating, .importPrivateKey, .importMnemonics:
            break
        }
        presentingViewController?.dismiss(animated: true)
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
