import UIKit
import MixinServices

class TIPInputPINViewController: ContinueButtonViewController {
    
    enum Action {
        case create(InitializeStep)
        case change(ChangeStep)
    }
    
    enum InitializeStep {
        case input
        case confirmation(step: UInt, previous: String)
    }
    
    enum ChangeStep {
        case verify
        case input(old: String)
        case confirmation(step: UInt, old: String, new: String)
    }
    
    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    private let action: Action
    private let confirmationSteps = 3
    
    private var isBusy = false {
        didSet {
            continueButton.isBusy = isBusy
            continueButton.isHidden = !isBusy
            pinField.receivesInput = !isBusy
        }
    }
    
    private var tipNavigationController: TIPNavigationViewController? {
        navigationController as? TIPNavigationViewController
    }
    
    init(action: Action) {
        self.action = action
        let nib = R.nib.tipInputPINView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !pinField.isFirstResponder {
            pinField.becomeFirstResponder()
        }
        pinField.clear()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        subtitleLabel.snp.makeConstraints { make in
            make.bottom.equalTo(keyboardLayoutGuide.snp.top).offset(-16)
        }
        pinField.becomeFirstResponder()
        switch action {
        case .create(.input):
            titleLabel.text = "Set a 6 digit Wallet PIN to create your first digital wallet."
            subtitleLabel.text = ""
        case .change(.verify):
            titleLabel.text = R.string.localizable.enter_your_pin()
            subtitleLabel.text = ""
        case .change(.input):
            titleLabel.text = R.string.localizable.set_new_pin()
            subtitleLabel.text = ""
        case let .create(.confirmation(step, _)), let .change(.confirmation(step, _, _)):
            switch step {
            case 0:
                titleLabel.text = R.string.localizable.pin_confirm_hint()
                subtitleLabel.text = R.string.localizable.pin_lost_hint()
            case 1:
                titleLabel.text = R.string.localizable.pin_confirm_again_hint()
                subtitleLabel.text = R.string.localizable.third_pin_confirm_hint()
            default:
                titleLabel.text = R.string.localizable.pin_confirm_again_hint()
                subtitleLabel.text = R.string.localizable.fourth_pin_confirm_hint()
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @IBAction func pinFieldEditingChanged(_ field: PinField) {
        guard !isBusy, pinField.text.count == pinField.numberOfDigits else {
            return
        }
        let pin = pinField.text
        
        switch action {
        case .create(.input), .change(.input):
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
            let next = TIPInputPINViewController(action: .create(.confirmation(step: 0, previous: pin)))
            navigationController?.pushViewController(next, animated: true)
        case let .create(.confirmation(step, previous)):
            guard pin == previous else {
                alert(R.string.localizable.wallet_password_not_equal(), cancelHandler: { _ in
                    self.tipNavigationController?.popToFirstInputPINViewController()
                })
                return
            }
            let next: UIViewController
            if step == confirmationSteps - 1 {
                next = TIPActionViewController(action: .create(pin: pin), context: nil)
            } else {
                next = TIPInputPINViewController(action: .create(.confirmation(step: step + 1, previous: pin)))
            }
            navigationController?.pushViewController(next, animated: true)
        case .change(.verify):
            isBusy = true
            AccountAPI.verify(pin: pin) { result in
                self.isBusy = false
                switch result {
                case .success:
                    AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                    let next = TIPInputPINViewController(action: .change(.input(old: pin)))
                    self.navigationController?.pushViewController(next, animated: true)
                case let .failure(error):
                    self.pinField.clear()
                    PINVerificationFailureHandler.handle(error: error) { (description) in
                        self.alert(description)
                    }
                }
            }
        case let .change(.input(old)):
            let next = TIPInputPINViewController(action: .change(.confirmation(step: 0, old: old, new: pin)))
            navigationController?.pushViewController(next, animated: true)
        case let .change(.confirmation(step, old, new)):
            guard pin == new else {
                alert(R.string.localizable.wallet_password_not_equal(), cancelHandler: { _ in
                    self.tipNavigationController?.popToFirstInputPINViewController()
                })
                return
            }
            let next: UIViewController
            if step == confirmationSteps - 1 {
                next = TIPActionViewController(action: .change(old: old, new: new), context: nil)
            } else {
                next = TIPInputPINViewController(action: .change(.confirmation(step: step + 1, old: old, new: new)))
            }
            navigationController?.pushViewController(next, animated: true)
        }
    }
    
    @objc private func applicationDidBecomeActive() {
        if !pinField.isFirstResponder {
            pinField.becomeFirstResponder()
        }
    }
    
}
