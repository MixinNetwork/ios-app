import UIKit
import MixinServices

final class PopupTipViewController: UIViewController {
    
    @IBOutlet weak var imageBackgroundView: GradientView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var bodyStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionTextView: IntroTextView!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    private let tip: PopupTip
    private let presentationManager = PopupPresentationManager()
    
    private var descriptionAttributes: [NSAttributedString.Key: Any] {
        let descriptionParagraph = NSMutableParagraphStyle()
        descriptionParagraph.lineHeightMultiple = 1.5
        descriptionParagraph.alignment = .center
        return [
            .font: UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 14)
            ),
            .foregroundColor: R.color.text_secondary()!,
            .paragraphStyle: descriptionParagraph,
        ]
    }
    
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
        descriptionTextView.textContainerInset = .zero
        descriptionTextView.textContainer.lineFragmentPadding = 0
        descriptionTextView.adjustsFontForContentSizeCategory = true
        
        let continueButtonTitle: String
        let cancelButtonTitle: String
        switch tip {
        case .appUpdate:
            imageView.image = R.image.tips_update()
            titleLabel.text = R.string.localizable.new_update_available()
            descriptionTextView.attributedText = NSAttributedString(
                string: R.string.localizable.new_update_available_desc(),
                attributes: descriptionAttributes
            )
            continueButtonTitle = R.string.localizable.update_now()
            cancelButtonTitle = R.string.localizable.not_now()
        case .recovery(let context):
            imageView.image = R.image.tips_recovery()
            titleLabel.text = R.string.localizable.recovery_kit()
            let description = R.string.localizable.recovery_kit_alert()
            let attributedDescription = NSMutableAttributedString(
                string: description,
                attributes: descriptionAttributes
            )
            let learnMoreRange = description.range(
                of: R.string.localizable.learn_more(),
                options: [.backwards, .caseInsensitive]
            )
            if let learnMoreRange {
                let linkRange = NSRange(learnMoreRange, in: description)
                attributedDescription.addAttributes(
                    [.foregroundColor: R.color.theme()!, .link: URL.recoveryKit],
                    range: linkRange
                )
            }
            descriptionTextView.attributedText = attributedDescription
            bodyStackView.setCustomSpacing(24, after: descriptionTextView)
            let optionsView = PopupTipRecoveryKitOptionsView(
                enabledOptions: context.enabledOptions
            )
            bodyStackView.addArrangedSubview(optionsView)
            continueButtonTitle = R.string.localizable.continue()
            cancelButtonTitle = switch context.intent {
            case .homePageInspection, .assetChangingConfirmation:
                R.string.localizable.not_now()
            case .logoutConfirmation:
                R.string.localizable.cancel()
            }
        case .notification:
            imageView.image = R.image.tips_notification()
            titleLabel.text = R.string.localizable.enable_push_notification()
            descriptionTextView.attributedText = NSAttributedString(
                string: R.string.localizable.notification_content(),
                attributes: descriptionAttributes
            )
            continueButtonTitle = R.string.localizable.enable_notifications()
            cancelButtonTitle = R.string.localizable.not_now()
        case .verifyMobileNumber:
            imageView.image = R.image.tips_verify_phone()
            titleLabel.text = R.string.localizable.verify_mobile_number()
            descriptionTextView.attributedText = NSAttributedString(
                string: R.string.localizable.periodic_sms_verification_benefits(),
                attributes: descriptionAttributes
            )
            continueButtonTitle = R.string.localizable.verify_now()
            cancelButtonTitle = R.string.localizable.not_now()
        case .appRating:
            assertionFailure("No preview for app rating. Call `AppStore.requestReview(in:)` instead.")
            continueButtonTitle = ""
            cancelButtonTitle = ""
        case .importPrivateKey:
            imageView.image = R.image.tips_import_private_key()
            titleLabel.text = R.string.localizable.import_private_key()
            descriptionTextView.attributedText = NSAttributedString(
                string: R.string.localizable.import_secret_description(R.string.localizable.private_key()),
                attributes: descriptionAttributes
            )
            continueButtonTitle = R.string.localizable.import_now()
            cancelButtonTitle = R.string.localizable.not_now()
        case .importMnemonics:
            imageView.image = R.image.tips_import_mnemonics()
            titleLabel.text = R.string.localizable.import_mnemonic_phrase()
            descriptionTextView.attributedText = NSAttributedString(
                string: R.string.localizable.import_secret_description(R.string.localizable.mnemonic_phrase()),
                attributes: descriptionAttributes
            )
            continueButtonTitle = R.string.localizable.import_now()
            cancelButtonTitle = R.string.localizable.not_now()
        case .addMobileNumber(let intent):
            imageView.image = R.image.tips_verify_phone()
            titleLabel.text = R.string.localizable.add_mobile_number()
            let description = switch intent {
            case .buyToken:
                R.string.localizable.add_mobile_number_reason_buy_token()
            case .setRecoveryContact:
                R.string.localizable.add_mobile_number_reason_set_recovery_contact()
            }
            descriptionTextView.attributedText = NSAttributedString(
                string: description,
                attributes: descriptionAttributes
            )
            continueButtonTitle = R.string.localizable.add_now()
            cancelButtonTitle = R.string.localizable.not_now()
        }
        
        continueButton.configuration?.attributedTitle = {
            var attributes = AttributeContainer()
            attributes.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 16, weight: .medium)
            )
            attributes.foregroundColor = .white
            return AttributedString(continueButtonTitle, attributes: attributes)
        }()
        continueButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        if var config = cancelButton.configuration {
            config.attributedTitle = {
                var attributes = AttributeContainer()
                attributes.font = UIFontMetrics.default.scaledFont(
                    for: .systemFont(ofSize: 16, weight: .medium)
                )
                attributes.foregroundColor = R.color.theme()
                return AttributedString(cancelButtonTitle, attributes: attributes)
            }()
            config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 0, bottom: 15, trailing: 0)
            cancelButton.configuration = config
        }
        cancelButton.titleLabel?.adjustsFontForContentSizeCategory = true
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
        case .recovery:
            presentingViewController?.dismiss(animated: true) {
                let recovery = RecoveryKitViewController()
                UIApplication.homeNavigationController?.pushViewController(recovery, animated: true)
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
        case .verifyMobileNumber:
            presentingViewController?.dismiss(animated: true) {
                let pin = VerifyMobileNumberPINValidationViewController(intent: .periodicVerification)
                UIApplication.homeNavigationController?.pushViewController(pin, animated: true)
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
        case .addMobileNumber:
            presentingViewController?.dismiss(animated: true) {
                let introduction = MobileNumberIntroductionViewController(action: .add)
                UIApplication.homeNavigationController?.pushViewController(introduction, animated: true)
            }
        }
    }
    
    @IBAction func cancel(_ sender: Any) {
        switch tip {
        case .recovery(let context):
            switch context.intent {
            case .assetChangingConfirmation(let onCancel):
                presentingViewController?.dismiss(animated: true, completion: onCancel)
                return
            default:
                break
            }
        default:
            break
        }
        
        switch tip {
        case .appUpdate:
            AppGroupUserDefaults.appUpdateTipDismissalDate = Date()
        case .recovery:
            AppGroupUserDefaults.User.recoveryKitTipDismissalDate = Date()
        case .notification:
            AppGroupUserDefaults.notificationTipDismissalDate = Date()
        case .verifyMobileNumber:
            AppGroupUserDefaults.User.verifyPhoneTipDismissalDate = Date()
        case .appRating, .importPrivateKey, .importMnemonics, .addMobileNumber:
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
        let height = view.systemLayoutSizeFitting(
            sizeToFit,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        let maxHeight = superview.bounds.height - superview.safeAreaInsets.top
        preferredContentSize.height = min(maxHeight, height)
    }
    
}
