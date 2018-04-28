import UIKit

class WalletPasswordViewController: UIViewController {

    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var tipsLabel: UILabel!

    private var transferData: PasswordTransferData?

    enum WalletPasswordType {
        case initPinStep1
        case initPinStep2(previous: String)
        case changePinStep1
        case changePinStep2(old: String)
        case changePinStep3(old: String, previous: String)
    }
    
    private var walletPasswordType = WalletPasswordType.initPinStep1

    override func viewDidLoad() {
        super.viewDidLoad()
        pinField.becomeFirstResponder()

        switch walletPasswordType {
        case .initPinStep1, .changePinStep1:
            container?.leftButton.setImage(#imageLiteral(resourceName: "ic_titlebar_close"), for: .normal)
        default:
            container?.leftButton.setImage(#imageLiteral(resourceName: "ic_titlebar_back"), for: .normal)
        }

        switch walletPasswordType {
        case .initPinStep1, .changePinStep2:
            tipsLabel.text = Localized.WALLET_PASSWORD_TIPS
        case .initPinStep2, .changePinStep3:
            tipsLabel.text = Localized.WALLET_PASSWORD_TIPS_AGAIN
        case .changePinStep1:
            tipsLabel.text = Localized.WALLET_PASSWORD_TIPS_VERIFY
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !pinField.isFirstResponder {
            pinField.becomeFirstResponder()
        }
        pinField.clear()
    }
    
    class func instance(walletPasswordType: WalletPasswordType, transferData: PasswordTransferData? = nil) -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "password") as! WalletPasswordViewController
        vc.walletPasswordType = walletPasswordType
        vc.transferData = transferData
        let title: String
        switch walletPasswordType {
        case .initPinStep1, .changePinStep2:
            title = Localized.WALLET_PASSWORD_TITLE
        case .initPinStep2, .changePinStep3:
            title = Localized.WALLET_PASSWORD_COFIRM_TITLE
        case .changePinStep1:
            title = Localized.WALLET_PASSWORD_VERIFY_TITLE
        }
        return ContainerViewController.instance(viewController: vc, title: title)
    }

    class func instance(fromChat user: UserItem, conversationId: String, asset: AssetItem?) -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "password") as! WalletPasswordViewController
        vc.walletPasswordType = .initPinStep1
        vc.transferData = PasswordTransferData(user: user, conversationId: conversationId, asset: asset)
        return ContainerViewController.instance(viewController: vc, title: Localized.WALLET_PASSWORD_TITLE)
    }



    @IBAction func pinChangedAction(_ sender: Any) {
        container?.rightButton.isEnabled = pinField.text.count == pinField.numberOfDigits
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

extension WalletPasswordViewController: ContainerViewControllerDelegate {

    func barRightButtonTappedAction() {
        let pin = pinField.text
        switch walletPasswordType {
        case .initPinStep1:
            let vc = WalletPasswordViewController.instance(walletPasswordType: .initPinStep2(previous: pin), transferData: transferData)
            navigationController?.pushViewController(vc, animated: true)
        case .initPinStep2(let previous):
            if previous == pin {
                container?.rightButton.isBusy = true
                AccountAPI.shared.updatePin(old: nil, new: pin, completion: { [weak self] (result) in
                    self?.container?.rightButton.isBusy = false
                    switch result {
                    case .success(let account):
                        WalletUserDefault.shared.lastInputPinTime = Date().timeIntervalSince1970
                        AccountAPI.shared.account = account
                        self?.updatePasswordSuccessfully(alertTitle: Localized.WALLET_SET_PASSWORD_SUCCESS)
                    case let .failure(error, didHandled):
                        guard !didHandled else {
                            return
                        }

                        self?.alert(error.description)
                    }
                })
            } else {
                alert(Localized.WALLET_PASSWORD_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.navigationController?.popViewController(animated: true)
                })
            }
        case .changePinStep1:
            container?.rightButton.isBusy = true
            AccountAPI.shared.verify(pin: pin, completion: { [weak self] (result) in
                guard let weakSelf = self else {
                    return
                }
                weakSelf.container?.rightButton.isBusy = false
                switch result {
                case .success:
                    WalletUserDefault.shared.lastInputPinTime = Date().timeIntervalSince1970
                    let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep2(old: pin), transferData: weakSelf.transferData)
                    weakSelf.navigationController?.pushViewController(vc, animated: true)
                case let .failure(error, didHandled):
                    weakSelf.pinField.clear()
                    guard !didHandled else {
                        return
                    }
                    weakSelf.alert(error.kind.localizedDescription ?? error.description)
                }
            })
        case .changePinStep2(let old):
            let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep3(old: old, previous: pin), transferData: transferData)
            navigationController?.pushViewController(vc, animated: true)
        case .changePinStep3(let old, let previous):
            if previous == pin {
                container?.rightButton.isBusy = true
                AccountAPI.shared.updatePin(old: old, new: pin, completion: { [weak self] (result) in
                    self?.container?.rightButton.isBusy = false
                    switch result {
                    case .success(let account):
                        WalletUserDefault.shared.lastInputPinTime = Date().timeIntervalSince1970
                        AccountAPI.shared.account = account
                        self?.updatePasswordSuccessfully(alertTitle: Localized.WALLET_CHANGE_PASSWORD_SUCCESS)
                    case let .failure(error, didHandled):
                        guard !didHandled else {
                            return
                        }

                        self?.alert(error.description)
                    }
                })
            } else {
                alert(Localized.WALLET_PASSWORD_INCONSISTENCY, cancelHandler: { [weak self](_) in
                    self?.navigationController?.popViewController(animated: true)
                })
            }
        }
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

    func textBarRightButton() -> String? {
        switch walletPasswordType {
        case .initPinStep2, .changePinStep3:
            return Localized.ACTION_DONE
        default:
            return Localized.ACTION_NEXT
        }
    }

    struct PasswordTransferData {
        let user: UserItem!
        let conversationId: String!
        let asset: AssetItem?
    }
}


