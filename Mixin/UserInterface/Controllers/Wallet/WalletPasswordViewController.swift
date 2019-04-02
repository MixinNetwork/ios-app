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
        case changePinStep1
        case changePinStep2(old: String)
        case changePinStep3(old: String, previous: String)
        case changePinStep4(old: String, previous: String)
    }

    enum DismissTarget {
        case wallet
        case transfer(user: UserItem)
        case changePhone
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
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "password") as! WalletPasswordViewController
        vc.walletPasswordType = walletPasswordType
        vc.dismissTarget = dismissTarget
        return vc
    }
    
    class func instance(dismissTarget: DismissTarget) -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "password") as! WalletPasswordViewController
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
                    self?.navigationController?.pushViewController(withBackChat: SendViewController.instance(asset: nil, type: .contact(user)))
                case .changePhone:
                    guard let navigation = weakSelf.navigationController else {
                        return
                    }
                    var viewControllers: [UIViewController] = navigation.viewControllers
                    while (viewControllers.count > 0 && viewControllers.last is WalletPasswordViewController) {
                        viewControllers.removeLast()
                    }
                    let viewController = ChangeNumberNavigationController(rootViewController: R.storyboard.contact.verifyPin()!)
                    navigation.present(viewController, animated: true, completion: {
                        navigation.setViewControllers(viewControllers, animated: false)
                    })
                }
            } else {
                weakSelf.popToLastController()
            }
        })
    }

    struct PasswordTransferData {
        let user: UserItem!
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
        
        var viewControllerToPush: WalletPasswordViewController?
        switch walletPasswordType {
        case .initPinStep1:
            viewControllerToPush = WalletPasswordViewController.instance(walletPasswordType: .initPinStep2(previous: pin), dismissTarget: dismissTarget)
        case .initPinStep2(let previous):
            if previous == pin {
                viewControllerToPush = WalletPasswordViewController.instance(walletPasswordType: .initPinStep3(previous: pin), dismissTarget: dismissTarget)
            } else {
                alert(Localized.WALLET_PIN_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.popToFirstInitController()
                })
            }
        case .initPinStep3(let previous):
            if previous == pin {
                isBusy = true
                AccountAPI.shared.updatePin(old: nil, new: pin, completion: { [weak self] (result) in
                    self?.isBusy = false
                    switch result {
                    case .success(let account):
                        WalletUserDefault.shared.lastInputPinTime = Date().timeIntervalSince1970
                        AccountAPI.shared.account = account
                        self?.updatePasswordSuccessfully(alertTitle: Localized.WALLET_SET_PASSWORD_SUCCESS)
                    case let .failure(error):
                        self?.alert(error.localizedDescription)
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
                    WalletUserDefault.shared.lastInputPinTime = Date().timeIntervalSince1970
                    let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep2(old: pin), dismissTarget: weakSelf.dismissTarget)
                    vc.continueButtonBottomConstant = weakSelf.continueButtonBottomConstant
                    weakSelf.navigationController?.pushViewController(vc, animated: true)
                case let .failure(error):
                    weakSelf.pinField.clear()
                    weakSelf.alert(error.localizedDescription)
                }
            })
        case .changePinStep2(let old):
            viewControllerToPush = WalletPasswordViewController.instance(walletPasswordType: .changePinStep3(old: old, previous: pin), dismissTarget: dismissTarget)
        case .changePinStep3(let old, let previous):
            if previous == pin {
                viewControllerToPush = WalletPasswordViewController.instance(walletPasswordType: .changePinStep4(old: old, previous: pin), dismissTarget: dismissTarget)
            } else {
                alert(Localized.WALLET_PIN_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.popToFirstInitController()
                })
            }
        case .changePinStep4(let old, let previous):
            if previous == pin {
                isBusy = true
                AccountAPI.shared.updatePin(old: old, new: pin, completion: { [weak self] (result) in
                    self?.isBusy = false
                    switch result {
                    case .success(let account):
                        if WalletUserDefault.shared.isBiometricPay {
                            Keychain.shared.storePIN(pin: pin)
                        }
                        WalletUserDefault.shared.checkPinInterval = WalletUserDefault.shared.checkMinInterval
                        WalletUserDefault.shared.lastInputPinTime = Date().timeIntervalSince1970
                        AccountAPI.shared.account = account
                        self?.updatePasswordSuccessfully(alertTitle: Localized.WALLET_CHANGE_PASSWORD_SUCCESS)
                    case let .failure(error):
                        self?.alert(error.localizedDescription)
                    }
                })
            } else {
                alert(Localized.WALLET_PIN_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.navigationController?.popViewController(animated: true)
                })
            }
        }
        if let vc = viewControllerToPush {
            vc.continueButtonBottomConstant = self.continueButtonBottomConstant
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
