import UIKit
import Alamofire
import MixinServices

final class TIPIntroViewController: UIViewController {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionTextLabel: TextLabel!
    @IBOutlet weak var noticeTextView: UITextView!
    @IBOutlet weak var nextButton: RoundedButton!
    @IBOutlet weak var actionDescriptionLabel: UILabel!
    
    @IBOutlet weak var noticeTextViewHeightConstraint: NSLayoutConstraint!
    
    enum Interruption {
        case unknown
        case none
        case inputNeeded(TIP.InterruptionContext)
        case noInputNeeded(TIPActionViewController.Action, Error)
    }
    
    private let intent: TIP.Action
    private let checkCounterTimeoutInterval: TimeInterval = 10
    
    private var interruption: Interruption
    
    private var tipNavigationController: TIPNavigationController? {
        navigationController as? TIPNavigationController
    }
    
    convenience init(intent: TIP.Action) {
        Logger.tip.info(category: "TIPIntro", message: "Init with intent: \(intent)")
        self.init(intent: intent, interruption: .unknown)
    }
    
    convenience init(context: TIP.InterruptionContext) {
        Logger.tip.info(category: "TIPIntro", message: "Init with context: \(context)")
        self.init(intent: context.action, interruption: .inputNeeded(context))
    }
    
    convenience init(action: TIPActionViewController.Action, changedNothingWith error: Error) {
        Logger.tip.info(category: "TIPIntro", message: "Init with action: \(action.debugDescription), error: \(error)")
        let intent: TIP.Action
        switch action {
        case .create:
            intent = .create
        case .change:
            intent = .change
        case .migrate:
            intent = .migrate
        }
        self.init(intent: intent, interruption: .noInputNeeded(action, error))
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    private init(intent: TIP.Action, interruption: Interruption) {
        self.intent = intent
        self.interruption = interruption
        let nib = R.nib.tipIntroView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateNavigationItem()
        contentStackView.setCustomSpacing(24, after: iconImageView)
        iconImageView.image = R.image.ic_tip()
        let description: String
        switch intent {
        case .create:
            titleLabel.text = R.string.localizable.create_pin()
            switch interruption {
            case .unknown, .none:
                description = R.string.localizable.tip_creation_introduction()
            case .inputNeeded, .noInputNeeded:
                description = R.string.localizable.creating_wallet_terminated_unexpectedly()
                reporter.report(event: .accountResumePIN, tags: ["type": "pin_create"])
            }
            setNoticeHidden(false)
        case .change:
            titleLabel.text = R.string.localizable.change_pin()
            switch interruption {
            case .unknown, .none:
                description = R.string.localizable.tip_introduction()
            case .inputNeeded, .noInputNeeded:
                description = R.string.localizable.changing_pin_terminated_unexpectedly()
                reporter.report(event: .accountResumePIN, tags: ["type": "pin_change"])
            }
            setNoticeHidden(false)
        case .migrate:
            titleLabel.text = R.string.localizable.upgrade_tip()
            switch interruption {
            case .unknown, .none:
                description = R.string.localizable.tip_introduction()
            case .inputNeeded, .noInputNeeded:
                description = R.string.localizable.upgrading_tip_terminated_unexpectedly()
                reporter.report(event: .accountResumePIN, tags: ["type": "pin_upgrade"])
            }
            setNoticeHidden(false)
        }
        descriptionTextLabel.text = description
        descriptionTextLabel.delegate = self
        noticeTextView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 14)
        lazy var linksMap: [NSRange: URL] = {
            let range = (description as NSString).range(of: R.string.localizable.learn_more(), options: [.backwards, .caseInsensitive])
            if range.location != NSNotFound && range.length != 0 {
                return [range: URL.tip]
            } else {
                return [:]
            }
        }()
        switch interruption {
        case .unknown:
            checkCounter()
            descriptionTextLabel.additionalLinksMap = linksMap
        case .none:
            descriptionTextLabel.additionalLinksMap = linksMap
            updateNextButtonAndStatusLabel(with: .waitingForUser)
        case .inputNeeded, .noInputNeeded:
            updateNextButtonAndStatusLabel(with: .waitingForUser)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if noticeTextViewHeightConstraint.constant != noticeTextView.contentSize.height {
            noticeTextViewHeightConstraint.constant = noticeTextView.contentSize.height
        }
    }
    
    @IBAction func continueToNext(_ sender: RoundedButton) {
        switch interruption {
        case .unknown:
            checkCounter()
        case .none:
            switch intent {
            case .create:
                let input = TIPFullscreenInputViewController(action: .create(.input))
                navigationController?.pushViewController(input, animated: true)
            case .change:
                let fromLegacy = false
                let input = TIPFullscreenInputViewController(action: .change(fromLegacy, .verify))
                navigationController?.pushViewController(input, animated: true)
            case .migrate:
                let validator = TIPPopupInputViewController(action: .migrate({ pin in
                    let action = TIPActionViewController(action: .migrate(pin: pin))
                    self.navigationController?.setViewControllers([action], animated: true)
                }))
                present(validator, animated: true)
            }
        case .inputNeeded(let context):
            let navigationController = self.tipNavigationController
            let validator = TIPPopupInputViewController(action: .continue(context, { [weak navigationController] in
                switch context.action {
                case .create:
                    reporter.report(event: .signUpEnd)
                case .change:
                    break
                case .migrate:
                    break
                }
                navigationController?.finish()
            }))
            present(validator, animated: true)
        case let .noInputNeeded(action, _):
            let viewController = TIPActionViewController(action: action)
            navigationController?.setViewControllers([viewController], animated: true)
        }
    }
    
    @objc private func close(_ sender: Any) {
        navigationController?.presentingViewController?.dismiss(animated: true)
    }
    
    @objc func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController(presentLoginLogsOnLongPressingTitle: true)
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "tip_intro"])
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
    
    private enum Status {
        case checkingCounter
        case counterCheckingFails
        case waitingForUser
    }
    
    private func updateNavigationItem() {
        switch (intent, interruption) {
        case (.change, .none):
            navigationItem.leftBarButtonItem = .tintedIcon(
                image: R.image.ic_title_close(),
                target: self,
                action: #selector(close(_:))
            )
        default:
            navigationItem.leftBarButtonItem = nil
        }
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
    }
    
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
                .foregroundColor: R.color.text_tertiary()!,
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
        updateNextButtonAndStatusLabel(with: .checkingCounter)
        Logger.tip.info(category: "TIPIntro", message: "Checking counter")
        Task {
            do {
                let context = try await TIP.checkCounter(timeoutInterval: checkCounterTimeoutInterval)
                await MainActor.run {
                    Logger.tip.info(category: "TIPIntro", message: "Got context: \(String(describing: context))")
                    if let context = context {
                        let intro = TIPIntroViewController(context: context)
                        navigationController?.setViewControllers([intro], animated: true)
                    } else {
                        interruption = .none
                        updateNextButtonAndStatusLabel(with: .waitingForUser)
                        updateNavigationItem()
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
            actionDescriptionLabel.textColor = R.color.text_tertiary()
        case .counterCheckingFails:
            nextButton.setTitle(R.string.localizable.retry(), for: .normal)
            nextButton.isBusy = false
            actionDescriptionLabel.text = R.string.localizable.connect_to_tip_network_failed()
            actionDescriptionLabel.textColor = .mixinRed
        case .waitingForUser:
            switch interruption {
            case .unknown, .none:
                setNextButtonTitleByIntent()
                actionDescriptionLabel.text = nil
            case .inputNeeded:
                nextButton.setTitle(R.string.localizable.continue(), for: .normal)
                actionDescriptionLabel.text = nil
            case let .noInputNeeded(_, error):
                nextButton.setTitle(R.string.localizable.retry(), for: .normal)
                actionDescriptionLabel.text = error.localizedDescription
                actionDescriptionLabel.textColor = .mixinRed
            }
            nextButton.isBusy = false
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
