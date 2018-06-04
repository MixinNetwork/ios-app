import UIKit
import KeychainAccess
import Bugsnag

class VerificationCodeViewController: LoginViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var verificationCodeField: VerificationCodeField!
    @IBOutlet weak var invalidCodeLabel: UILabel!
    var resendButton: CountDownButton!
    
    private let resendInterval = 60
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let loginInfo = loginInfo {
            let displayNumber = "+\(loginInfo.callingCode) \(loginInfo.mobileNumber)"
            titleLabel.text = Localized.NAVIGATION_TITLE_ENTER_VERIFICATION_CODE(mobileNumber: displayNumber)
        }
        resendButton = bottomWrapperView.leftButton
        resendButton.addTarget(self, action: #selector(resendAction(_:)), for: .touchUpInside)
        resendButton.normalTitle = Localized.BUTTON_TITLE_RESEND_CODE
        resendButton.pendingTitleTemplate = Localized.BUTTON_TITLE_RESEND_CODE_PENDING
        resendButton.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        resendButton.beginCountDown(resendInterval)
        verificationCodeField.becomeFirstResponder()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        resendButton.restartTimerIfNeeded()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        resendButton.releaseTimer()
    }

    deinit {
        ReCaptchaManager.shared.clean()
    }
    
    @IBAction func checkVerificationCodeAction(_ sender: Any) {
        guard let verificationId = loginInfo.verificationId else {
            return
        }
        invalidCodeLabel.isHidden = true
        let code = verificationCodeField.text
        if code.count != verificationCodeField.numberOfDigits {
            continueButton.isEnabled = false
        } else {
            guard !continueButton.isBusy else {
                return
            }
            continueButton.isEnabled = true
            continueButton.isBusy = true
            guard let keyPair = KeyUtil.generateRSAKeyPair() else {
                UIApplication.trackError("KeyUtil", action: "generateRSAKeyPair failed")
                continueButton.isBusy = false
                return
            }
            let registerationId = Int(SignalProtocol.shared.getRegistrationId())
            let request = AccountRequest.createAccountRequest(verificationCode: code, registrationId: registerationId, pin: nil, sessionSecret: keyPair.publicKey)
            AccountAPI.shared.login(verificationId: verificationId, accountRequest: request, completion: { [weak self] (result) in
                guard let weakSelf = self else {
                    return
                }
                weakSelf.continueButton.isBusy = false
                switch result {
                case let .success(account):
                    AccountUserDefault.shared.storePinToken(pinToken: KeyUtil.rsaDecrypt(pkString: keyPair.privateKeyPem, sessionId: account.session_id, pinToken: account.pin_token))
                    AccountUserDefault.shared.storeToken(token: keyPair.privateKeyPem)
                    AccountAPI.shared.account = account
                    MixinDatabase.shared.configure(reset: true)
                    DispatchQueue.global().async {
                        UserDAO.shared.updateAccount(account: account)
                    }
                    if account.full_name.isEmpty {
                        let vc = UsernameViewController.instance()
                        weakSelf.navigationController?.pushViewController(vc, animated: true)
                    } else {
                        ContactAPI.shared.syncContacts()
                        AppDelegate.current.window?.rootViewController = HomeViewController.instance()
                    }
                case let .failure(error):
                    weakSelf.continueButton.isEnabled = true
                    weakSelf.continueButton.isBusy = false
                    if error.code == 20113 {
                        weakSelf.verificationCodeField.clear()
                        weakSelf.verificationCodeField.showError()
                        weakSelf.invalidCodeLabel.isHidden = false
                    } else {
                        weakSelf.alert(error.localizedDescription)
                    }
                }
            })
        }
    }
    
    override func continueAction(_ sender: Any) {
        checkVerificationCodeAction(sender)
    }
    
    @objc func resendAction(_ sender: Any) {
        resendButton.isBusy = true
        sendCode(reCaptchaToken: nil)
    }
    
    private func sendCode(reCaptchaToken token: String?) {
        AccountAPI.shared.sendCode(to: loginInfo.fullNumber, reCaptchaToken: token, purpose: .session) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case let .success(verification):
                weakSelf.loginInfo.verificationId = verification.id
                weakSelf.resendButton.isBusy = false
                weakSelf.resendButton.beginCountDown(weakSelf.resendInterval)
            case let .failure(error):
                if error.code == 10005 {
                    ReCaptchaManager.shared.validate(onViewController: weakSelf) { (result) in
                        switch result {
                        case .success(let token):
                            self?.sendCode(reCaptchaToken: token)
                        default:
                            self?.resendButton.isBusy = false
                        }
                    }
                } else {
                    weakSelf.alert(error.localizedDescription)
                    weakSelf.resendButton.isBusy = false
                }
            }
        }
    }
    
    static func instance(loginInfo: LoginInfo) -> VerificationCodeViewController {
        let vc = Storyboard.login.instantiateViewController(withIdentifier: "VerificationCode") as! VerificationCodeViewController
        vc.loginInfo = loginInfo
        return vc
    }

}
