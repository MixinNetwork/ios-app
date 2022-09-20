import UIKit
import Alamofire
import MixinServices

class TIPIntroViewController: UIViewController {
    
    enum Interruption {
        case unknown
        case none
        case confirmed(TIP.InterruptionContext)
    }
    
    private enum Status {
        case checkingCounter
        case counterCheckingFails
        case waitingForUser
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionTextLabel: TextLabel!
    @IBOutlet weak var noticeTextView: UITextView!
    @IBOutlet weak var nextButton: RoundedButton!
    @IBOutlet weak var actionDescriptionLabel: UILabel!
    
    @IBOutlet weak var noticeTextViewHeightConstraint: NSLayoutConstraint!
    
    private let intent: TIP.Action
    private let checkCounterTimeoutInterval: TimeInterval = 5
    
    private var interruption: Interruption
    
    private var tipNavigationController: TIPNavigationViewController? {
        navigationController as? TIPNavigationViewController
    }
    
    init(intent: TIP.Action) {
        Logger.tip.info(category: "TIPIntro", message: "Init with intent: \(intent)")
        self.intent = intent
        self.interruption = .unknown
        let nib = R.nib.tipIntroView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    init(context: TIP.InterruptionContext) {
        Logger.tip.info(category: "TIPIntro", message: "Init with context: \(context)")
        self.intent = context.action
        self.interruption = .confirmed(context)
        let nib = R.nib.tipIntroView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        contentStackView.setCustomSpacing(24, after: iconImageView)
        descriptionTextLabel.delegate = self
        noticeTextView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 14)
        let description: String
        switch intent {
        case .create:
            titleLabel.text = R.string.localizable.create_pin()
            switch interruption {
            case .unknown, .none:
                description = R.string.localizable.tip_creation_introduction()
            case .confirmed:
                description = R.string.localizable.creating_wallet_terminated_unexpectedly()
            }
            setNoticeHidden(false)
        case .change:
            titleLabel.text = R.string.localizable.change_pin()
            switch interruption {
            case .unknown, .none:
                description = R.string.localizable.tip_introduction()
            case .confirmed:
                description = R.string.localizable.changing_pin_terminated_unexpectedly()
            }
            setNoticeHidden(false)
        case .migrate:
            titleLabel.text = R.string.localizable.upgrade_tip()
            switch interruption {
            case .unknown, .none:
                description = R.string.localizable.tip_introduction()
            case .confirmed:
                description = R.string.localizable.upgrading_tip_terminated_unexpectedly()
            }
            setNoticeHidden(false)
        }
        descriptionTextLabel.text = description
        lazy var linksMap: [NSRange: URL] = {
            let range = (description as NSString).range(of: R.string.localizable.learn_more(), options: [.backwards, .caseInsensitive])
            if range.location != NSNotFound && range.length != 0 {
                return [range: URL.pinTIP]
            } else {
                return [:]
            }
        }()
        switch interruption {
        case .unknown:
            checkCounter()
            descriptionTextLabel.additionalLinksMap = linksMap
        case .confirmed:
            updateNextButtonAndStatusLabel(with: .waitingForUser)
        case .none:
            descriptionTextLabel.additionalLinksMap = linksMap
            updateNextButtonAndStatusLabel(with: .waitingForUser)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if noticeTextViewHeightConstraint.constant != noticeTextView.contentSize.height {
            noticeTextViewHeightConstraint.constant = noticeTextView.contentSize.height
        }
    }
    
    @IBAction func continueToNext(_ sender: Any) {
        switch interruption {
        case .unknown:
            checkCounter()
        case .none:
            switch intent {
            case .create:
                let input = TIPFullscreenInputViewController(action: .create(.input))
                navigationController?.pushViewController(input, animated: true)
            case .change:
                let fromLegacy: Bool
                switch TIP.status {
                case .ready:
                    fromLegacy = false
                case .needsMigrate:
                    fromLegacy = true
                case .unknown, .needsInitialize:
                    assertionFailure("Invalid TIP status")
                    return
                }
                let input = TIPFullscreenInputViewController(action: .change(fromLegacy, .verify))
                navigationController?.pushViewController(input, animated: true)
            case .migrate:
                let validator = TIPPopupInputViewController(action: .migrate({ pin in
                    let action = TIPActionViewController(action: .migrate(pin: pin))
                    self.navigationController?.pushViewController(action, animated: true)
                }))
                present(validator, animated: true)
            }
        case .confirmed(let context):
            switch context.action {
            case .migrate:
                let validator = TIPPopupInputViewController(action: .migrate({ pin in
                    let action = TIPActionViewController(action: .migrate(pin: pin))
                    self.navigationController?.pushViewController(action, animated: true)
                }))
                present(validator, animated: true)
            case .create, .change:
                let validator = TIPPopupInputViewController(action: .continue(context, {
                    let tipNavigationController = self.tipNavigationController
                    self.dismiss(animated: true) {
                        tipNavigationController?.dismissToDestination(animated: true)
                    }
                }))
                present(validator, animated: true)
            }
        }
    }
    
}

extension TIPIntroViewController: CoreTextLabelDelegate {
    
    func coreTextLabel(_ label: CoreTextLabel, didSelectURL url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    func coreTextLabel(_ label: CoreTextLabel, didLongPressOnURL url: URL) {
        
    }
    
}

extension TIPIntroViewController {
    
    private func setNoticeHidden(_ hidden: Bool) {
        if hidden {
            noticeTextView.isHidden = true
        } else {
            let style = NSMutableParagraphStyle()
            style.paragraphSpacing = 8
            style.tabStops = [NSTextTab(textAlignment: .left, location: 15, options: [:])]
            style.defaultTabInterval = 15
            style.firstLineHeadIndent = 0
            style.headIndent = 13
            
            let noticeAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: R.color.text_accessory()!,
                .font: UIFont.preferredFont(forTextStyle: .footnote),
                .paragraphStyle: style,
            ]
            let warningAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: R.color.red()!,
                .font: UIFont.preferredFont(forTextStyle: .footnote),
                .paragraphStyle: style,
            ]
            
            let notice = "•  " + R.string.localizable.please_use_when_network_is_connected() + "\n•  " + R.string.localizable.please_keep_app_in_foreground() + "\n•  "
            let attributedText = NSMutableAttributedString(string: notice, attributes: noticeAttributes)
            let warning = NSAttributedString(string: R.string.localizable.process_can_not_be_stop(), attributes: warningAttributes)
            attributedText.append(warning)
            
            noticeTextView.attributedText = attributedText
            noticeTextView.isHidden = false
        }
    }
    
    private func checkCounter() {
        guard let account = LoginManager.shared.account else {
            return
        }
        updateNextButtonAndStatusLabel(with: .checkingCounter)
        Logger.tip.info(category: "TIPIntro", message: "Checking counter")
        Task {
            do {
                let context = try await TIP.checkCounter(with: account, timeoutInterval: checkCounterTimeoutInterval)
                await MainActor.run {
                    Logger.tip.info(category: "TIPIntro", message: "Got context: \(String(describing: context))")
                    if let context = context {
                        let intro = TIPIntroViewController(context: context)
                        navigationController?.setViewControllers([intro], animated: true)
                    } else {
                        interruption = .none
                        updateNextButtonAndStatusLabel(with: .waitingForUser)
                    }
                }
            } catch {
                await MainActor.run {
                    Logger.tip.error(category: "TIPIntro", message: "Failed to check counter: \(error)")
                    updateNextButtonAndStatusLabel(with: .counterCheckingFails)
                }
            }
        }
    }
    
    private func updateNextButtonAndStatusLabel(with status: Status) {
        switch status {
        case .checkingCounter:
            setNextButtonTitleByIntent()
            nextButton.isBusy = true
            actionDescriptionLabel.text = R.string.localizable.trying_connect_tip_network()
            actionDescriptionLabel.textColor = R.color.text_desc()
        case .counterCheckingFails:
            nextButton.setTitle(R.string.localizable.retry(), for: .normal)
            nextButton.isBusy = false
            actionDescriptionLabel.text = R.string.localizable.connect_to_tip_network_failed()
            actionDescriptionLabel.textColor = .mixinRed
        case .waitingForUser:
            switch interruption {
            case .unknown, .none:
                setNextButtonTitleByIntent()
            case .confirmed:
                nextButton.setTitle(R.string.localizable.continue(), for: .normal)
            }
            nextButton.isBusy = false
            actionDescriptionLabel.text = nil
        }
    }
    
    private func setNextButtonTitleByIntent() {
        switch intent {
        case .create, .change:
            nextButton.setTitle(R.string.localizable.start(), for: .normal)
        case .migrate:
            nextButton.setTitle(R.string.localizable.upgrade(), for: .normal)
        }
    }
    
}
