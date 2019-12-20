import UIKit

class WalletPasswordViewController: ContinueButtonViewController {

    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    
    enum WalletPasswordType {
        case initPinStep1
        case initPinStep2(previous: String)
        case initPinStep3(previous: String)
        case initPinStep4(previous: String)
        case changePinStep1
        case changePinStep2(old: String)
        case changePinStep3(old: String, previous: String)
        case changePinStep4(old: String, previous: String)
        case changePinStep5(old: String, previous: String)
    }

    enum DismissTarget {
        case wallet
        case transfer(user: UserItem)
        case changePhone
        case setEmergencyContact
    }

    private var dismissTarget: DismissTarget?
    private var walletPasswordType = WalletPasswordType.initPinStep1
    private var isBusy = false {
        didSet {
            continueButton.isBusy = isBusy
            continueButton.isHidden = !isBusy
            pinField.receivesInput = !isBusy
        }
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if !pinField.isFirstResponder {
            pinField.becomeFirstResponder()
        }
        pinField.clear()
    }
    
    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    class func instance(walletPasswordType: WalletPasswordType, dismissTarget: DismissTarget?) -> WalletPasswordViewController {
        let vc = R.storyboard.wallet.password()!
        vc.walletPasswordType = walletPasswordType
        vc.dismissTarget = dismissTarget
        return vc
    }
    
    class func instance(dismissTarget: DismissTarget) -> UIViewController {
        let vc = R.storyboard.wallet.password()!
        vc.walletPasswordType = .initPinStep1
        vc.dismissTarget = dismissTarget
        return vc
    }

    private func popToFirstInitController() {
        guard let viewController = navigationController?.viewControllers.first(where: { $0 is WalletPasswordViewController }) else {
            return
        }
        navigationController?.popToViewController(viewController, animated: true)
    }

    private func popToLastController() {
        guard let viewController = navigationController?.viewControllers.reversed().first(where: { !($0 is WalletPasswordViewController) }) else {
            return
        }

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
                    self?.navigationController?.pushViewController(withBackRoot: WalletViewController.instance())
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
                return
            }
        default:
            break
        }
        
        switch walletPasswordType {
        case .initPinStep1:
            let vc = WalletPasswordViewController.instance(walletPasswordType: .initPinStep2(previous: pin), dismissTarget: dismissTarget)
            navigationController?.pushViewController(vc, animated: true)
        case .initPinStep2(let previous):
            if previous == pin {
                let vc = WalletPasswordViewController.instance(walletPasswordType: .initPinStep3(previous: pin), dismissTarget: dismissTarget)
                navigationController?.pushViewController(vc, animated: true)
            } else {
                alert(Localized.WALLET_PIN_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.popToFirstInitController()
                })
            }
        case .initPinStep3(let previous):
            if previous == pin {
                let vc = WalletPasswordViewController.instance(walletPasswordType: .initPinStep4(previous: pin), dismissTarget: dismissTarget)
                navigationController?.pushViewController(vc, animated: true)
            } else {
                alert(Localized.WALLET_PIN_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.popToFirstInitController()
                })
            }
        case .initPinStep4(let previous):
            if previous == pin {
                isBusy = true
                AccountAPI.shared.updatePin(old: nil, new: pin, completion: { [weak self] (result) in
                    self?.isBusy = false
                    switch result {
                    case .success(let account):
                        AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                        LoginManager.shared.account = account
                        self?.updatePasswordSuccessfully(alertTitle: Localized.WALLET_SET_PASSWORD_SUCCESS)
                    case let .failure(error):
                        if error.code == 429 {
                            self?.alert(R.string.localizable.wallet_password_too_many_requests())
                        } else {
                            self?.alert(error.localizedDescription)
                        }
                    }
                })
            } else {
                alert(Localized.WALLET_PIN_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.popToFirstInitController()
                })
            }
        case .changePinStep1:
            isBusy = true
            AccountAPI.shared.verify(pin: pin, completion: { [weak self] (result) in
                guard let weakSelf = self else {
                    return
                }
                weakSelf.isBusy = false
                switch result {
                case .success:
                    AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                    let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep2(old: pin), dismissTarget: weakSelf.dismissTarget)
                    weakSelf.navigationController?.pushViewController(vc, animated: true)
                case let .failure(error):
                    weakSelf.pinField.clear()
                    if error.code == 429 {
                        weakSelf.alert(R.string.localizable.wallet_password_too_many_requests())
                    } else {
                        weakSelf.alert(error.localizedDescription)
                    }
                }
            })
        case .changePinStep2(let old):
            let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep3(old: old, previous: pin), dismissTarget: dismissTarget)
            navigationController?.pushViewController(vc, animated: true)
        case .changePinStep3(let old, let previous):
            if previous == pin {
                let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep4(old: old, previous: pin), dismissTarget: dismissTarget)
                navigationController?.pushViewController(vc, animated: true)
            } else {
                alert(Localized.WALLET_PIN_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.popToFirstInitController()
                })
            }
        case .changePinStep4(let old, let previous):
            if previous == pin {
                let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep5(old: old, previous: pin), dismissTarget: dismissTarget)
                navigationController?.pushViewController(vc, animated: true)
            } else {
                alert(Localized.WALLET_PIN_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.popToFirstInitController()
                })
            }
        case .changePinStep5(let old, let previous):
            if previous == pin {
                isBusy = true
                AccountAPI.shared.updatePin(old: old, new: pin, completion: { [weak self] (result) in
                    self?.isBusy = false
                    switch result {
                    case .success(let account):
                        if AppGroupUserDefaults.Wallet.payWithBiometricAuthentication {
                            Keychain.shared.storePIN(pin: pin)
                        }
                        AppGroupUserDefaults.Wallet.periodicPinVerificationInterval = PeriodicPinVerificationInterval.min
                        AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                        LoginManager.shared.account = account
                        self?.updatePasswordSuccessfully(alertTitle: Localized.WALLET_CHANGE_PASSWORD_SUCCESS)
                    case let .failure(error):
                        if error.code == 429 {
                            self?.alert(R.string.localizable.wallet_password_too_many_requests())
                        } else {
                            self?.alert(error.localizedDescription)
                        }
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
