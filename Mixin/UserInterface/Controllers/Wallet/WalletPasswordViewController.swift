import UIKit
import MixinServices

class WalletPasswordViewController: ContinueButtonViewController {

    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    
    enum WalletPasswordType: CustomDebugStringConvertible {
        
        case initPinStep1
        case initPinStep2(previous: String)
        case initPinStep3(previous: String)
        case initPinStep4(previous: String)
        case changePinStep1
        case changePinStep2(old: String)
        case changePinStep3(old: String, previous: String)
        case changePinStep4(old: String, previous: String)
        case changePinStep5(old: String, previous: String)
        
        var debugDescription: String {
            switch self {
            case .initPinStep1:
                return "init1"
            case .initPinStep2:
                return "init2"
            case .initPinStep3:
                return "init3"
            case .initPinStep4:
                return "init4"
            case .changePinStep1:
                return "change1"
            case .changePinStep2:
                return "change2"
            case .changePinStep3:
                return "change3"
            case .changePinStep4:
                return "change4"
            case .changePinStep5:
                return "change5"
            }
        }
        
    }

    enum DismissTarget {
        case wallet
        case transfer(user: UserItem)
        case changePhone
        case setEmergencyContact
    }
    
    private var source: StaticString = ""
    private var dismissTarget: DismissTarget?
    private var walletPasswordType = WalletPasswordType.initPinStep1
    private var isBusy = false {
        didSet {
            continueButton.isBusy = isBusy
            continueButton.isHidden = !isBusy
            pinField.receivesInput = !isBusy
        }
    }
    
    deinit {
        Logger.general.info(category: "SetPIN", message: "\(self) deinited")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pinField.delegate = self
        pinField.becomeFirstResponder()
        switch walletPasswordType {
        case .initPinStep1:
            titleLabel.text = Localized.WALLET_PIN_CREATE_TITLE
            subtitleLabel.text = ""
            backButton.setImage(R.image.ic_title_close(), for: .normal)
        case .initPinStep2, .changePinStep3:
            titleLabel.text = Localized.WALLET_PIN_CONFIRM_TITLE
            subtitleLabel.text = Localized.WALLET_PIN_CONFIRM_SUBTITLE
            backButton.setImage(R.image.ic_title_back(), for: .normal)
        case .initPinStep3, .changePinStep4:
            titleLabel.text = Localized.WALLET_PIN_CONFIRM_AGAIN_TITLE
            subtitleLabel.text = Localized.WALLET_PIN_CONFIRM_AGAIN_SUBTITLE
            backButton.setImage(R.image.ic_title_back(), for: .normal)
        case .initPinStep4, .changePinStep5:
            titleLabel.text = Localized.WALLET_PIN_CONFIRM_AGAIN_TITLE
            subtitleLabel.text = R.string.localizable.wallet_pin_more_confirm()
            backButton.setImage(R.image.ic_title_back(), for: .normal)
        case .changePinStep1:
            titleLabel.text = Localized.WALLET_PIN_VERIFY_TITLE
            subtitleLabel.text = ""
            backButton.setImage(R.image.ic_title_close(), for: .normal)
        case .changePinStep2:
            titleLabel.text = Localized.WALLET_PIN_NEW_TITLE
            subtitleLabel.text = ""
            backButton.setImage(R.image.ic_title_back(), for: .normal)
        }
        Logger.general.info(category: "SetPIN", message: "\(self) viewDidLoad with step: \(walletPasswordType), source: \(source), destination: \(String(describing: dismissTarget))")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if !pinField.isFirstResponder {
            pinField.becomeFirstResponder()
        }
        pinField.clear()
        Logger.general.info(category: "SetPIN", message: "\(self) viewWillAppear")
    }
    
    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    class func instance(walletPasswordType: WalletPasswordType, source: StaticString, dismissTarget: DismissTarget?) -> WalletPasswordViewController {
        let vc = R.storyboard.wallet.password()!
        vc.walletPasswordType = walletPasswordType
        vc.source = source
        vc.dismissTarget = dismissTarget
        return vc
    }
    
    class func instance(dismissTarget: DismissTarget, source: StaticString) -> UIViewController {
        let vc = R.storyboard.wallet.password()!
        vc.walletPasswordType = .initPinStep1
        vc.source = source
        vc.dismissTarget = dismissTarget
        return vc
    }

    private func popToFirstInitController() {
        guard let viewController = navigationController?.viewControllers.first(where: { $0 is WalletPasswordViewController }) else {
            Logger.general.error(category: "SetPIN", message: "\(self) Failed to pop to first step")
            return
        }
        navigationController?.popToViewController(viewController, animated: true)
        Logger.general.info(category: "SetPIN", message: "\(self) Pop to first step")
    }

    private func popToLastController() {
        guard let viewController = navigationController?.viewControllers.reversed().first(where: { !($0 is WalletPasswordViewController) }) else {
            Logger.general.error(category: "SetPIN", message: "\(self) Failed to pop all set PINs")
            return
        }
        Logger.general.info(category: "SetPIN", message: "\(self) Pop all set PINs")
        navigationController?.popToViewController(viewController, animated: true)
    }

    private func updatePasswordSuccessfully(alertTitle: String) {
        alert(alertTitle, cancelHandler: { [weak self](_) in
            guard let weakSelf = self else {
                return
            }
            if let target = weakSelf.dismissTarget {
                switch target {
                case .wallet:
                    let wallet = R.storyboard.wallet.wallet()!
                    self?.navigationController?.pushViewController(withBackRoot: wallet)
                case let .transfer(user):
                    self?.navigationController?.pushViewController(withBackChat: TransferOutViewController.instance(asset: nil, type: .contact(user)))
                case .changePhone:
                    let vc = VerifyPinNavigationController(rootViewController: ChangeNumberVerifyPinViewController())
                    self?.removeWalletPasswordAndPresent(vc)
                case .setEmergencyContact:
                    let vc = VerifyPinNavigationController(rootViewController: EmergencyContactVerifyPinViewController())
                    self?.removeWalletPasswordAndPresent(vc)
                }
            } else {
                weakSelf.popToLastController()
            }
        })
    }
    
    private func removeWalletPasswordAndPresent(_ viewController: UIViewController) {
        guard let navigationController = navigationController else {
            Logger.general.error(category: "SetPIN", message: "\(self) Failed to remove set PIN controller")
            return
        }
        var viewControllers: [UIViewController] = navigationController.viewControllers
        while (viewControllers.count > 0 && viewControllers.last is WalletPasswordViewController) {
            viewControllers.removeLast()
        }
        navigationController.present(viewController, animated: true, completion: {
            navigationController.setViewControllers(viewControllers, animated: false)
        })
    }
    
}

extension WalletPasswordViewController: MixinNavigationAnimating {
    
    var pushAnimation: MixinNavigationPushAnimation {
        switch walletPasswordType {
        case .changePinStep1, .initPinStep1:
            return .present
        default:
            return .push
        }
    }
    
    var popAnimation: MixinNavigationPopAnimation {
        switch walletPasswordType {
        case .changePinStep1, .initPinStep1:
            return .dismiss
        default:
            return .pop
        }
    }

}

extension WalletPasswordViewController: PinFieldDelegate {

    func inputFinished(pin: String) {
        guard !isBusy else {
            return
        }
        let pin = pinField.text

        switch walletPasswordType {
        case .initPinStep1, .changePinStep2:
            if pin == "123456" || Set(pin).count < 3 {
                pinField.clear()
                alert(Localized.WALLET_PIN_TOO_SIMPLE)
                Logger.general.info(category: "SetPIN", message: "\(self) Too simple PIN detected")
                return
            }
        default:
            break
        }
        
        switch walletPasswordType {
        case .initPinStep1:
            let vc = WalletPasswordViewController.instance(walletPasswordType: .initPinStep2(previous: pin), source: source, dismissTarget: dismissTarget)
            navigationController?.pushViewController(vc, animated: true)
        case .initPinStep2(let previous):
            if previous == pin {
                let vc = WalletPasswordViewController.instance(walletPasswordType: .initPinStep3(previous: pin), source: source, dismissTarget: dismissTarget)
                navigationController?.pushViewController(vc, animated: true)
            } else {
                alert(Localized.WALLET_PIN_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.popToFirstInitController()
                })
            }
        case .initPinStep3(let previous):
            if previous == pin {
                let vc = WalletPasswordViewController.instance(walletPasswordType: .initPinStep4(previous: pin), source: source, dismissTarget: dismissTarget)
                navigationController?.pushViewController(vc, animated: true)
            } else {
                alert(Localized.WALLET_PIN_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.popToFirstInitController()
                })
            }
        case .initPinStep4(let previous):
            if previous == pin {
                isBusy = true
                Logger.general.info(category: "SetPIN", message: "\(self) Begin init PIN")
                AccountAPI.updatePin(old: nil, new: pin, completion: { [weak self] (result) in
                    self?.isBusy = false
                    switch result {
                    case .success(let account):
                        AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                        LoginManager.shared.setAccount(account)
                        self?.updatePasswordSuccessfully(alertTitle: Localized.WALLET_SET_PASSWORD_SUCCESS)
                        Logger.general.info(category: "SetPIN", message: "\(String(describing: self)) Successfully inited PIN")
                    case let .failure(error):
                        PINVerificationFailureHandler.handle(error: error) { (description) in
                            self?.alert(description)
                        }
                        Logger.general.info(category: "SetPIN", message: "\(String(describing: self)) PIN init failed with: \(error)")
                    }
                })
            } else {
                alert(Localized.WALLET_PIN_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.popToFirstInitController()
                })
            }
        case .changePinStep1:
            isBusy = true
            Logger.general.info(category: "SetPIN", message: "\(self) Begin verify PIN")
            AccountAPI.verify(pin: pin, completion: { [weak self] (result) in
                guard let weakSelf = self else {
                    return
                }
                weakSelf.isBusy = false
                switch result {
                case .success:
                    AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                    let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep2(old: pin), source: weakSelf.source, dismissTarget: weakSelf.dismissTarget)
                    weakSelf.navigationController?.pushViewController(vc, animated: true)
                    Logger.general.info(category: "SetPIN", message: "\(weakSelf) Successfully verified PIN")
                case let .failure(error):
                    weakSelf.pinField.clear()
                    PINVerificationFailureHandler.handle(error: error) { (description) in
                        self?.alert(description)
                    }
                    Logger.general.info(category: "SetPIN", message: "\(weakSelf) PIN verification failed for: \(error)")
                }
            })
        case .changePinStep2(let old):
            let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep3(old: old, previous: pin), source: source, dismissTarget: dismissTarget)
            navigationController?.pushViewController(vc, animated: true)
        case .changePinStep3(let old, let previous):
            if previous == pin {
                let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep4(old: old, previous: pin), source: source, dismissTarget: dismissTarget)
                navigationController?.pushViewController(vc, animated: true)
            } else {
                alert(Localized.WALLET_PIN_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.popToFirstInitController()
                })
            }
        case .changePinStep4(let old, let previous):
            if previous == pin {
                let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep5(old: old, previous: pin), source: source, dismissTarget: dismissTarget)
                navigationController?.pushViewController(vc, animated: true)
            } else {
                alert(Localized.WALLET_PIN_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.popToFirstInitController()
                })
            }
        case .changePinStep5(let old, let previous):
            if previous == pin {
                isBusy = true
                Logger.general.info(category: "SetPIN", message: "\(self) Begin change PIN")
                AccountAPI.updatePin(old: old, new: pin, completion: { [weak self] (result) in
                    self?.isBusy = false
                    switch result {
                    case .success(let account):
                        if AppGroupUserDefaults.Wallet.payWithBiometricAuthentication {
                            Keychain.shared.storePIN(pin: pin)
                        }
                        AppGroupUserDefaults.Wallet.periodicPinVerificationInterval = PeriodicPinVerificationInterval.min
                        AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                        LoginManager.shared.setAccount(account)
                        self?.updatePasswordSuccessfully(alertTitle: Localized.WALLET_CHANGE_PASSWORD_SUCCESS)
                        Logger.general.info(category: "SetPIN", message: "\(String(describing: self)) Successfully changed PIN")
                    case let .failure(error):
                        PINVerificationFailureHandler.handle(error: error) { (description) in
                            self?.alert(description)
                        }
                        Logger.general.info(category: "SetPIN", message: "\(String(describing: self)) Failed to change pin for: \(error)")
                    }
                })
            } else {
                alert(Localized.WALLET_PIN_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.navigationController?.popViewController(animated: true)
                })
            }
        }
    }
}
