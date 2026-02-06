import UIKit
import MixinServices

final class TIPFullscreenInputViewController: UIViewController {
    
    enum Action: CustomDebugStringConvertible {
        
        case create(InitializeStep)
        case change(_ fromLegacy: Bool, _ step: ChangeStep)
        
        var debugDescription: String {
            switch self {
            case .create(let step):
                return "create(\(step.debugDescription))"
            case let .change(fromLegacy, step):
                return "change(\(fromLegacy), \(step))"
            }
        }
        
    }
    
    enum InitializeStep: CustomDebugStringConvertible {
        
        case input
        case confirmation(step: UInt, previous: String)
        
        var debugDescription: String {
            switch self {
            case .input:
                return "input"
            case let .confirmation(step, _):
                return "confirmation step \(step)"
            }
        }
        
    }
    
    enum ChangeStep: CustomDebugStringConvertible {
        
        case verify
        case input(old: String)
        case confirmation(step: UInt, old: String, new: String)
        
        var debugDescription: String {
            switch self {
            case .verify:
                return "verify"
            case .input:
                return "input"
            case let .confirmation(step, _, _):
                return "confirmation step \(step)"
            }
        }
        
    }
    
    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var continueButton: ConfigurationBasedBusyButton!
    
    private let action: Action
    private let confirmationStepCount = 2
    
    private var isBusy = false {
        didSet {
            continueButton.isBusy = isBusy
            pinField.receivesInput = !isBusy
        }
    }
    
    private var tipNavigationController: TIPNavigationController? {
        navigationController as? TIPNavigationController
    }
    
    init(action: Action) {
        self.action = action
        let nib = R.nib.tipFullscreenInputView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        switch action {
        case .create(.input):
            reporter.report(event: .signUpPINSet)
            titleLabel.text = R.string.localizable.tip_create_pin_title()
            subtitleLabel.text = ""
        case .change(_, .verify):
            titleLabel.text = R.string.localizable.enter_your_old_pin()
            subtitleLabel.text = ""
        case .change(_, .input):
            titleLabel.text = R.string.localizable.set_new_pin()
            subtitleLabel.text = ""
        case let .create(.confirmation(step, _)), let .change(_, .confirmation(step, _, _)):
            switch step {
            case 0:
                titleLabel.text = R.string.localizable.pin_confirm_hint()
                subtitleLabel.text = R.string.localizable.pin_lost_hint()
            default:
                titleLabel.text = R.string.localizable.pin_confirm_again_hint()
                subtitleLabel.text = R.string.localizable.third_pin_confirm_hint()
            }
        }
        continueButton.snp.makeConstraints { make in
            make.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
                .offset(-26)
        }
        continueButton.configuration?.attributedTitle = {
            var attributes = AttributeContainer()
            attributes.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 16, weight: .medium)
            )
            return AttributedString(
                R.string.localizable.continue(),
                attributes: attributes
            )
        }()
        pinField.becomeFirstResponder()
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !pinField.isFirstResponder {
            pinField.becomeFirstResponder()
        }
        pinField.clear()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Logger.tip.info(category: "TIPFullscreenInput", message: "View did appear with action: \(action.debugDescription)")
    }
    
    @IBAction func pinFieldEditingChanged(_ field: PinField) {
        guard !isBusy, pinField.text.count == pinField.numberOfDigits else {
            return
        }
        let pin = pinField.text
        
        switch action {
        case .create(.input), .change(_, .input):
            if pin == "123456" || Set(pin).count < 3 {
                pinField.clear()
                alert(R.string.localizable.wallet_password_unsafe())
                return
            }
        default:
            break
        }
        
        switch action {
        case .create(.input):
            let next = TIPFullscreenInputViewController(action: .create(.confirmation(step: 0, previous: pin)))
            navigationController?.pushViewController(next, animated: true)
        case let .create(.confirmation(step, previous)):
            guard pin == previous else {
                alert(R.string.localizable.wallet_password_not_equal(), cancelHandler: { _ in
                    self.tipNavigationController?.popToFirstFullscreenInput()
                })
                return
            }
            if step == confirmationStepCount - 1 {
                let action = TIPActionViewController(action: .create(pin: pin))
                navigationController?.setViewControllers([action], animated: true)
            } else {
                let next = TIPFullscreenInputViewController(action: .create(.confirmation(step: step + 1, previous: pin)))
                navigationController?.pushViewController(next, animated: true)
            }
        case let .change(fromLegacy, .verify):
            isBusy = true
            AccountAPI.verify(pin: pin) { result in
                self.isBusy = false
                switch result {
                case .success:
                    Logger.tip.info(category: "TIPFullscreenInput", message: "PIN verified")
                    AppGroupUserDefaults.Wallet.lastPINVerifiedDate = Date()
                    let next = TIPFullscreenInputViewController(action: .change(fromLegacy, .input(old: pin)))
                    self.navigationController?.pushViewController(next, animated: true)
                case let .failure(error):
                    Logger.tip.error(category: "TIPFullscreenInput", message: "PIN verification failed: \(error)")
                    self.pinField.clear()
                    PINVerificationFailureHandler.handle(error: error) { (description) in
                        self.alert(description)
                    }
                }
            }
        case let .change(fromLegacy, .input(old)):
            let next = TIPFullscreenInputViewController(action: .change(fromLegacy, .confirmation(step: 0, old: old, new: pin)))
            navigationController?.pushViewController(next, animated: true)
        case let .change(fromLegacy, .confirmation(step, old, new)):
            guard pin == new else {
                alert(R.string.localizable.wallet_password_not_equal(), cancelHandler: { _ in
                    self.tipNavigationController?.popToFirstFullscreenInput()
                })
                return
            }
            if step == confirmationStepCount - 1 {
                let action: TIPActionViewController.Action
                if fromLegacy {
                    action = .change(old: .legacy(old), new: new)
                } else {
                    action = .change(old: .tip(old), new: new)
                }
                let viewController = TIPActionViewController(action: action)
                navigationController?.setViewControllers([viewController], animated: true)
            } else {
                let next = TIPFullscreenInputViewController(action: .change(fromLegacy, .confirmation(step: step + 1, old: old, new: new)))
                navigationController?.pushViewController(next, animated: true)
            }
        }
    }
    
    @objc private func applicationDidBecomeActive() {
        if !pinField.isFirstResponder {
            pinField.becomeFirstResponder()
        }
    }
    
}
