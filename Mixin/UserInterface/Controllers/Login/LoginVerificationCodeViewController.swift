import UIKit
import Firebase

class LoginVerificationCodeViewController: VerificationCodeViewController {
    
    var context: LoginContext!

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
                weakSelf.context.hasEmergencyContact = verification.hasEmergencyContact
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
                    Reporter.report(error: error)
                    weakSelf.alert(error.localizedDescription)
                    weakSelf.resendButton.isBusy = false
                }
            }
        }
    }
    
    func login() {
        isBusy = true
        guard let keyPair = KeyUtil.generateRSAKeyPair() else {
            Reporter.report(error: MixinError.generateRsaKeyPair)
            isBusy = false
            return
        }
        let code = verificationCodeField.text
        let registrationId = Int(SignalProtocol.shared.getRegistrationId())
        login(code: code, registrationId: registrationId, keyPair: keyPair)
    }
    
    func login(code: String, registrationId: Int, keyPair: KeyUtil.RSAKeyPair) {
        let request = AccountRequest(code: code, registrationId: registrationId, pin: nil, sessionSecret: keyPair.publicKey)
        AccountAPI.shared.login(verificationId: context.verificationId, accountRequest: request, completion: { [weak self] (result) in
            DispatchQueue.global().async {
                self?.handleLoginResult(result, privateKeyPem: keyPair.privateKeyPem)
            }
        })
    }
    
    func handleLoginResult(_ result: APIResult<Account>, privateKeyPem: String) {
        switch result {
        case let .success(account):
            let pinToken = KeyUtil.rsaDecrypt(pkString: privateKeyPem, sessionId: account.session_id, pinToken: account.pin_token)
            AppGroupUserDefaults.Account.pinToken = pinToken
            AppGroupUserDefaults.Account.sessionSecret = privateKeyPem
            MixinDatabase.shared.initDatabase(clearSentSenderKey: AppGroupUserDefaults.User.isLogoutByServer)
            TaskDatabase.shared.initDatabase()
            LoginManager.shared.account = account
            AppGroupUserDefaults.User.localVersion = AppGroupUserDefaults.User.version
            
            if account.full_name.isEmpty {
                Reporter.report(event: .fir(AnalyticsEventSignUp))
            } else if HomeViewController.showChangePhoneNumberTips {
                Reporter.report(event: .fir(AnalyticsEventLogin), userInfo: ["source": "emergency"])
            } else {
                Reporter.report(event: .fir(AnalyticsEventLogin), userInfo: ["source": "normal"])
            }
            
            DispatchQueue.main.sync {
                let voipToken = UIApplication.appDelegate().voipToken
                if !voipToken.isEmpty {
                    AccountAPI.shared.updateSession(voipToken: voipToken)
                }
            }

            var backupExist = false
            if let backupDir = backupUrl {
                backupExist = backupDir.appendingPathComponent(backupDatabaseName).isStoredCloud || backupDir.appendingPathComponent("mixin.backup.db").isStoredCloud
            }

            if AppGroupUserDefaults.User.isLogoutByServer || !backupExist {
                AppGroupUserDefaults.User.isLogoutByServer = false
                UserDAO.shared.updateAccount(account: account)
                DispatchQueue.main.sync {
                    if account.full_name.isEmpty {
                        let vc = UsernameViewController()
                        self.navigationController?.pushViewController(vc, animated: true)
                    } else {
                        ContactAPI.shared.syncContacts()
                        AppDelegate.current.window.rootViewController = makeInitialViewController()
                    }
                }
            } else {
                DispatchQueue.main.sync {
                    AppGroupUserDefaults.Account.canRestoreChat = true
                    AppDelegate.current.window.rootViewController = makeInitialViewController()
                }
            }
            UIApplication.shared.setShortcutItemsEnabled(true)
        case let .failure(error):
            DispatchQueue.main.sync {
                self.handleVerificationCodeError(error)
            }
        }
    }
    
}
