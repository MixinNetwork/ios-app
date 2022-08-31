import UIKit
import MixinServices

class WalletPasswordViewController: ContinueButtonViewController {

    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var textLabel: TextLabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    
    @IBOutlet weak var textLabelHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var textLabelLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var textLabelTrailingConstraint: NSLayoutConstraint!
    
    enum WalletPasswordType {
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
    
    private var lastViewWidth: CGFloat = 0
    private var dismissTarget: DismissTarget?
    private var walletPasswordType = WalletPasswordType.changePinStep1
    private var isBusy = false {
        didSet {
            continueButton.isBusy = isBusy
            continueButton.isHidden = !isBusy
            pinField.receivesInput = !isBusy
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pinField.addTarget(self, action: #selector(pinFieldEditingChanged(_:)), for: .editingChanged)
        pinField.becomeFirstResponder()
        
        textLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        textLabel.lineSpacing = 4
        textLabel.textColor = .title
        textLabel.detectLinks = false
        
        switch walletPasswordType {
        case .changePinStep3:
            textLabel.text = R.string.localizable.pin_confirm_hint()
            subtitleLabel.text = R.string.localizable.pin_lost_hint()
            backButton.setImage(R.image.ic_title_back(), for: .normal)
        case .changePinStep4:
            textLabel.text = R.string.localizable.pin_confirm_again_hint()
            subtitleLabel.text = R.string.localizable.third_pin_confirm_hint()
            backButton.setImage(R.image.ic_title_back(), for: .normal)
        case .changePinStep5:
            textLabel.text = R.string.localizable.pin_confirm_again_hint()
            subtitleLabel.text = R.string.localizable.fourth_pin_confirm_hint()
            backButton.setImage(R.image.ic_title_back(), for: .normal)
        case .changePinStep1:
            textLabel.text = R.string.localizable.enter_your_pin()
            subtitleLabel.text = ""
            backButton.setImage(R.image.ic_title_close(), for: .normal)
        case .changePinStep2:
            textLabel.text = R.string.localizable.set_new_pin()
            subtitleLabel.text = ""
            backButton.setImage(R.image.ic_title_back(), for: .normal)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if !pinField.isFirstResponder {
            pinField.becomeFirstResponder()
        }
        pinField.clear()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if view.bounds.width != lastViewWidth {
            let labelWidth = view.bounds.width
                - textLabelLeadingConstraint.constant
                - textLabelTrailingConstraint.constant
            let sizeToFitLabel = CGSize(width: labelWidth, height: UIView.layoutFittingExpandedSize.height)
            textLabelHeightConstraint.constant = textLabel.sizeThatFits(sizeToFitLabel).height
            lastViewWidth = view.bounds.width
        }
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
    
    @objc private func applicationDidBecomeActive() {
        if !pinField.isFirstResponder {
            pinField.becomeFirstResponder()
        }
    }
}

extension WalletPasswordViewController: MixinNavigationAnimating {
    
    var pushAnimation: MixinNavigationPushAnimation {
        switch walletPasswordType {
        case .changePinStep1:
            return .present
        default:
            return .push
        }
    }
    
    var popAnimation: MixinNavigationPopAnimation {
        switch walletPasswordType {
        case .changePinStep1:
            return .dismiss
        default:
            return .pop
        }
    }

}

extension WalletPasswordViewController {
    
    @objc private func pinFieldEditingChanged(_ pinField: PinField) {
        guard !isBusy, pinField.text.count == pinField.numberOfDigits else {
            return
        }
        let pin = pinField.text

        switch walletPasswordType {
        case .changePinStep2:
            if pin == "123456" || Set(pin).count < 3 {
                pinField.clear()
                alert(R.string.localizable.wallet_password_unsafe())
                return
            }
        default:
            break
        }
        
        switch walletPasswordType {
        case .changePinStep1:
            isBusy = true
            AccountAPI.verify(pin: pin, completion: { [weak self] (result) in
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
                    PINVerificationFailureHandler.handle(error: error) { (description) in
                        self?.alert(description)
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
                alert(R.string.localizable.wallet_password_not_equal(), cancelHandler: { [weak self](_) in
                    self?.popToFirstInitController()
                })
            }
        case .changePinStep4(let old, let previous):
            if previous == pin {
                let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep5(old: old, previous: pin), dismissTarget: dismissTarget)
                navigationController?.pushViewController(vc, animated: true)
            } else {
                alert(R.string.localizable.wallet_password_not_equal(), cancelHandler: { [weak self](_) in
                    self?.popToFirstInitController()
                })
            }
        case .changePinStep5(let old, let previous):
            if previous == pin {
                isBusy = true
                AccountAPI.updatePINWithoutTIP(old: old, new: pin, completion: { [weak self] (result) in
                    self?.isBusy = false
                    switch result {
                    case .success(let account):
                        if AppGroupUserDefaults.Wallet.payWithBiometricAuthentication {
                            Keychain.shared.storePIN(pin: pin)
                        }
                        AppGroupUserDefaults.Wallet.periodicPinVerificationInterval = PeriodicPinVerificationInterval.min
                        AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                        LoginManager.shared.setAccount(account)
                        self?.updatePasswordSuccessfully(alertTitle: R.string.localizable.change_pin_successfully())
                    case let .failure(error):
                        PINVerificationFailureHandler.handle(error: error) { (description) in
                            self?.alert(description)
                        }
                    }
                })
            } else {
                alert(R.string.localizable.wallet_password_not_equal(), cancelHandler: { [weak self](_) in
                    self?.navigationController?.popViewController(animated: true)
                })
            }
        }
    }
    
}

extension WalletPasswordViewController: CoreTextLabelDelegate {
    
    func coreTextLabel(_ label: CoreTextLabel, didSelectURL url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    func coreTextLabel(_ label: CoreTextLabel, didLongPressOnURL url: URL) {
        
    }
    
}
