import UIKit

class WalletPasswordViewController: UIViewController {

    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var tipsLabel: UILabel!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var nextButton: StateResponsiveButton!

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

    private var transferData: PasswordTransferData?
    private var walletPasswordType = WalletPasswordType.initPinStep1

    override func viewDidLoad() {
        super.viewDidLoad()
        pinField.becomeFirstResponder()

        switch walletPasswordType {
        case .initPinStep1:
            titleLabel.text = Localized.WALLET_PIN_INIT_TITLE
            tipsLabel.text = Localized.WALLET_PIN_INIT_TIPS1
            backButton.setImage(#imageLiteral(resourceName: "ic_titlebar_close"), for: .normal)
            nextButton.setTitle(Localized.ACTION_NEXT, for: .normal)
            subtitleLabel.text = "1/4"
        case .initPinStep2:
            titleLabel.text = Localized.WALLET_PIN_CONFIRM_TITLE
            tipsLabel.text = Localized.WALLET_PIN_INIT_TIPS2
            backButton.setImage(#imageLiteral(resourceName: "ic_titlebar_back"), for: .normal)
            nextButton.setTitle(Localized.ACTION_NEXT, for: .normal)
            subtitleLabel.text = "2/4"
        case .initPinStep3:
            titleLabel.text = Localized.WALLET_PIN_CONFIRM_TITLE
            tipsLabel.text = Localized.WALLET_PIN_INIT_TIPS3
            backButton.setImage(#imageLiteral(resourceName: "ic_titlebar_back"), for: .normal)
            nextButton.setTitle(Localized.ACTION_NEXT, for: .normal)
            subtitleLabel.text = "3/4"
        case .initPinStep4:
            titleLabel.text = Localized.WALLET_PIN_CONFIRM_TITLE
            tipsLabel.text = Localized.WALLET_PIN_INIT_TIPS4
            backButton.setImage(#imageLiteral(resourceName: "ic_titlebar_back"), for: .normal)
            nextButton.setTitle(Localized.ACTION_DONE, for: .normal)
            subtitleLabel.text = "4/4"
        case .changePinStep1:
            titleLabel.text = Localized.WALLET_PASSWORD_VERIFY_TITLE
            tipsLabel.text = Localized.WALLET_PIN_VERIFY_TIPS
            backButton.setImage(#imageLiteral(resourceName: "ic_titlebar_close"), for: .normal)
            nextButton.setTitle(Localized.ACTION_NEXT, for: .normal)
            subtitleLabel.text = "1/5"
        case .changePinStep2:
            titleLabel.text = Localized.WALLET_PIN_NEW_TITLE
            tipsLabel.text = Localized.WALLET_PIN_INIT_TIPS1
            backButton.setImage(#imageLiteral(resourceName: "ic_titlebar_back"), for: .normal)
            nextButton.setTitle(Localized.ACTION_NEXT, for: .normal)
            subtitleLabel.text = "2/5"
        case .changePinStep3:
            titleLabel.text = Localized.WALLET_PIN_CONFIRM_TITLE
            tipsLabel.text = Localized.WALLET_PIN_INIT_TIPS2
            backButton.setImage(#imageLiteral(resourceName: "ic_titlebar_back"), for: .normal)
            nextButton.setTitle(Localized.ACTION_NEXT, for: .normal)
            subtitleLabel.text = "3/5"
        case .changePinStep4:
            titleLabel.text = Localized.WALLET_PIN_CONFIRM_TITLE
            tipsLabel.text = Localized.WALLET_PIN_INIT_TIPS3
            backButton.setImage(#imageLiteral(resourceName: "ic_titlebar_back"), for: .normal)
            nextButton.setTitle(Localized.ACTION_NEXT, for: .normal)
            subtitleLabel.text = "4/5"
        case .changePinStep5:
            titleLabel.text = Localized.WALLET_PIN_CONFIRM_TITLE
            tipsLabel.text = Localized.WALLET_PIN_INIT_TIPS4
            backButton.setImage(#imageLiteral(resourceName: "ic_titlebar_back"), for: .normal)
            nextButton.setTitle(Localized.ACTION_DONE, for: .normal)
            subtitleLabel.text = "5/5"
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !pinField.isFirstResponder {
            pinField.becomeFirstResponder()
        }
        pinField.clear()
    }

    @IBAction func pinChangedAction(_ sender: Any) {
        nextButton.isEnabled = pinField.text.count == pinField.numberOfDigits
    }

    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func nextAction(_ sender: Any) {
        let pin = pinField.text

        switch walletPasswordType {
        case .initPinStep1, .changePinStep2:
            if pin == "123456" || Set(pin).count < 3 {
                pinField.clear()
                errorLabel.isHidden = false
                return
            }
            errorLabel.isHidden = true
        default:
            break
        }

        switch walletPasswordType {
        case .initPinStep1:
            let vc = WalletPasswordViewController.instance(walletPasswordType: .initPinStep2(previous: pin), transferData: transferData)
            navigationController?.pushViewController(vc, animated: true)
        case .initPinStep2(let previous):
            if previous == pin {
                let vc = WalletPasswordViewController.instance(walletPasswordType: .initPinStep3(previous: pin), transferData: transferData)
                navigationController?.pushViewController(vc, animated: true)
            } else {
                alert(Localized.WALLET_PIN_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.popToFirstInitController()
                })
            }
        case .initPinStep3(let previous):
            if previous == pin {
                let vc = WalletPasswordViewController.instance(walletPasswordType: .initPinStep4(previous: pin), transferData: transferData)
                navigationController?.pushViewController(vc, animated: true)
            } else {
                alert(Localized.WALLET_PIN_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.popToFirstInitController()
                })
            }
        case .initPinStep4(let previous):
            if previous == pin {
                nextButton.isBusy = true
                AccountAPI.shared.updatePin(old: nil, new: pin, completion: { [weak self] (result) in
                    self?.nextButton.isBusy = false
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
            nextButton.isBusy = true
            AccountAPI.shared.verify(pin: pin, completion: { [weak self] (result) in
                guard let weakSelf = self else {
                    return
                }
                weakSelf.nextButton.isBusy = false
                switch result {
                case .success:
                    WalletUserDefault.shared.lastInputPinTime = Date().timeIntervalSince1970
                    let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep2(old: pin), transferData: weakSelf.transferData)
                    weakSelf.navigationController?.pushViewController(vc, animated: true)
                case let .failure(error):
                    weakSelf.pinField.clear()
                    weakSelf.alert(error.localizedDescription)
                }
            })
        case .changePinStep2(let old):
            let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep3(old: old, previous: pin), transferData: transferData)
            navigationController?.pushViewController(vc, animated: true)
        case .changePinStep3(let old, let previous):
            if previous == pin {
                let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep4(old: old, previous: pin), transferData: transferData)
                navigationController?.pushViewController(vc, animated: true)
            } else {
                alert(Localized.WALLET_PIN_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.popToFirstInitController()
                })
            }
        case .changePinStep4(let old, let previous):
            if previous == pin {
                let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep5(old: old, previous: pin), transferData: transferData)
                navigationController?.pushViewController(vc, animated: true)
            } else {
                alert(Localized.WALLET_PIN_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.popToFirstInitController()
                })
            }
        case .changePinStep5(let old, let previous):
            if previous == pin {
                nextButton.isBusy = true
                AccountAPI.shared.updatePin(old: old, new: pin, completion: { [weak self] (result) in
                    self?.nextButton.isBusy = false
                    switch result {
                    case .success(let account):
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
    }
    

    class func instance(walletPasswordType: WalletPasswordType, transferData: PasswordTransferData? = nil) -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "password") as! WalletPasswordViewController
        vc.walletPasswordType = walletPasswordType
        vc.transferData = transferData
        return vc
    }

    class func instance(fromChat user: UserItem, conversationId: String, asset: AssetItem?) -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "password") as! WalletPasswordViewController
        vc.walletPasswordType = .initPinStep1
        vc.transferData = PasswordTransferData(user: user, conversationId: conversationId, asset: asset)
        return vc
    }

    private func popToFirstInitController() {
        guard let viewController = navigationController?.viewControllers.first(where: { $0 is WalletPasswordViewController }) else {
            return
        }
        navigationController?.popToViewController(viewController, animated: true)
    }

    private func updatePasswordSuccessfully(alertTitle: String) {
        alert(alertTitle, cancelHandler: { [weak self](_) in
            guard let weakSelf = self else {
                return
            }
            if let transferData = weakSelf.transferData {
                self?.navigationController?.pushViewController(withBackChat: TransferViewController.instance(user: transferData.user, conversationId: transferData.conversationId, asset: transferData.asset))
            } else {
                self?.navigationController?.pushViewController(withBackRoot: WalletViewController.instance())
            }
        })
    }

    struct PasswordTransferData {
        let user: UserItem!
        let conversationId: String!
        let asset: AssetItem?
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
        return .pop
    }

}
