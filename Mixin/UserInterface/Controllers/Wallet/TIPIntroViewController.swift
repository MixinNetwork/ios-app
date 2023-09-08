import UIKit
import Alamofire
import MixinServices

class TIPIntroViewController: IntroViewController {
    
    enum Interruption {
        case unknown
        case none
        case inputNeeded(TIP.InterruptionContext)
        case noInputNeeded(TIPActionViewController.Action, Error)
    }
    
    private enum Status {
        case checkingCounter
        case counterCheckingFails
        case waitingForUser
    }
    
    var isDismissAllowed: Bool {
        switch interruption {
        case .none, .noInputNeeded:
            return true
        case .unknown, .inputNeeded:
            return false
        }
    }
    
    private let intent: TIP.Action
    private let checkCounterTimeoutInterval: TimeInterval = 5
    
    private var interruption: Interruption
    
    private var tipNavigationController: TIPNavigationViewController? {
        navigationController as? TIPNavigationViewController
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
        super.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
            }
            setNoticeHidden(false)
        case .change:
            titleLabel.text = R.string.localizable.change_pin()
            switch interruption {
            case .unknown, .none:
                description = R.string.localizable.tip_introduction()
            case .inputNeeded, .noInputNeeded:
                description = R.string.localizable.changing_pin_terminated_unexpectedly()
            }
            setNoticeHidden(false)
        case .migrate:
            titleLabel.text = R.string.localizable.upgrade_tip()
            switch interruption {
            case .unknown, .none:
                description = R.string.localizable.tip_introduction()
            case .inputNeeded, .noInputNeeded:
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
        case .none:
            descriptionTextLabel.additionalLinksMap = linksMap
            updateNextButtonAndStatusLabel(with: .waitingForUser)
        case .inputNeeded, .noInputNeeded:
            updateNextButtonAndStatusLabel(with: .waitingForUser)
        }
    }
    
    override func continueToNext(_ sender: RoundedButton) {
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
                    Logger.tip.error(category: "TIPIntro", message: "Invalid status: \(TIP.status)")
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
        case .inputNeeded(let context):
            let validator = TIPPopupInputViewController(action: .continue(context, {
                let tipNavigationController = self.tipNavigationController
                self.dismiss(animated: true) {
                    tipNavigationController?.dismissToDestination(animated: true)
                }
            }))
            present(validator, animated: true)
        case let .noInputNeeded(action, _):
            let viewController = TIPActionViewController(action: action)
            navigationController?.setViewControllers([viewController], animated: true)
        }
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
                        tipNavigationController?.updateBackButtonAlpha(animated: true)
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
                actionDescriptionLabel.text = nil
            case .inputNeeded:
                nextButton.setTitle(R.string.localizable.continue(), for: .normal)
                actionDescriptionLabel.text = nil
            case let .noInputNeeded(_, error):
                nextButton.setTitle(R.string.localizable.retry(), for: .normal)
                if let error = error as? TIPNode.Error {
                    actionDescriptionLabel.text = error.description
                } else {
                    actionDescriptionLabel.text = error.localizedDescription
                }
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
