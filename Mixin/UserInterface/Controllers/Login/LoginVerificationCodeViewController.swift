import UIKit

class LoginVerificationCodeViewController: VerificationCodeViewController {
    
    var context: LoginContext!
    
    private lazy var backupAvailabilityQuery = BackupAvailabilityQuery()
    
    deinit {
        ReCaptchaManager.shared.clean()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let displayNumber = "+\(context.callingCode) \(context.mobileNumber)"
        titleLabel.text = Localized.NAVIGATION_TITLE_ENTER_VERIFICATION_CODE(mobileNumber: displayNumber)
    }
    
    override func verificationCodeFieldEditingChanged(_ sender: Any) {
        let code = verificationCodeField.text
        let codeCountMeetsRequirement = code.count == verificationCodeField.numberOfDigits
        continueButton.isHidden = !codeCountMeetsRequirement
        if !isBusy && codeCountMeetsRequirement {
            login()
        }
    }
    
    override func continueAction(_ sender: Any) {
        login()
    }
    
    override func requestVerificationCode(reCaptchaToken token: String?) {
        AccountAPI.shared.sendCode(to: context.fullNumber, reCaptchaToken: token, purpose: .session) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case let .success(verification):
                weakSelf.context.verificationId = verification.id
                weakSelf.resendButton.isBusy = false
                weakSelf.resendButton.beginCountDown(weakSelf.resendInterval)
            case let .failure(error):
                if error.code == 10005 {
                    ReCaptchaManager.shared.validate(onViewController: weakSelf) { (result) in
                        switch result {
                        case .success(let token):
                            self?.requestVerificationCode(reCaptchaToken: token)
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
    
    func login() {
        isBusy = true
        guard let keyPair = KeyUtil.generateRSAKeyPair() else {
            UIApplication.trackError("KeyUtil", action: "generateRSAKeyPair failed")
            isBusy = false
            return
        }
        let code = verificationCodeField.text
        let registerationId = Int(SignalProtocol.shared.getRegistrationId())
        let request = AccountRequest.createAccountRequest(verificationCode: code, registrationId: registerationId, pin: nil, sessionSecret: keyPair.publicKey)
        AccountAPI.shared.login(verificationId: context.verificationId, accountRequest: request, completion: { [weak self] (result) in
            DispatchQueue.global().async {
                guard let weakSelf = self else {
                    return
                }
                switch result {
                case let .success(account):
                    AccountUserDefault.shared.storePinToken(pinToken: KeyUtil.rsaDecrypt(pkString: keyPair.privateKeyPem, sessionId: account.session_id, pinToken: account.pin_token))
                    AccountUserDefault.shared.storeToken(token: keyPair.privateKeyPem)
                    AccountAPI.shared.account = account
                    
                    let sema = DispatchSemaphore(value: 0)
                    var backupExist = false
                    DispatchQueue.main.sync {
                        let voipToken = UIApplication.appDelegate().voipToken
                        if !voipToken.isEmpty {
                            AccountAPI.shared.updateSession(deviceToken: "", voip_token: voipToken)
                        }
                        weakSelf.backupAvailabilityQuery.fileExist(callback: { (exist) in
                            backupExist = exist
                            sema.signal()
                        })
                    }
                    sema.wait()
                    if CommonUserDefault.shared.hasForceLogout || !backupExist {
                        CommonUserDefault.shared.hasForceLogout = false
                        MixinDatabase.shared.configure(reset: true)
                        UserDAO.shared.updateAccount(account: account)
                        DispatchQueue.main.sync {
                            if account.full_name.isEmpty {
                                let vc = UsernameViewController.instance()
                                weakSelf.navigationController?.pushViewController(vc, animated: true)
                            } else {
                                ContactAPI.shared.syncContacts()
                                AppDelegate.current.window?.rootViewController = makeInitialViewController()
                            }
                        }
                    } else {
                        DispatchQueue.main.sync {
                            AccountUserDefault.shared.hasRestoreChat = true
                            AccountUserDefault.shared.hasRestoreFilesAndVideos = true
                            AppDelegate.current.window?.rootViewController = makeInitialViewController()
                        }
                    }
                case let .failure(error):
                    DispatchQueue.main.sync {
                        weakSelf.continueButton.isHidden = false
                        weakSelf.continueButton.isBusy = false
                        if error.code == 20113 {
                            weakSelf.verificationCodeField.clear()
                            weakSelf.verificationCodeField.showError()
                            UIApplication.showHud(style: .error, text: Localized.TEXT_INVALID_VERIFICATION_CODE)
                        } else {
                            weakSelf.alert(error.localizedDescription)
                        }
                    }
                }
            }
        })
    }
    
}
