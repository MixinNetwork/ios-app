import UIKit
import MixinServices

class LoginVerificationCodeViewController: VerificationCodeViewController {
    
    var context: LoginContext!

    deinit {
        CaptchaManager.shared.clean()
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
    
    override func requestVerificationCode(captchaToken token: CaptchaToken?) {
        AccountAPI.sendCode(to: context.fullNumber, captchaToken: token, purpose: .session) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case let .success(verification):
                weakSelf.context.verificationId = verification.id
                weakSelf.context.hasEmergencyContact = verification.hasEmergencyContact
                weakSelf.resendButton.isBusy = false
                weakSelf.resendButton.beginCountDown(weakSelf.resendInterval)
            case .failure(.requiresCaptcha):
                CaptchaManager.shared.validate(on: weakSelf) { (result) in
                    switch result {
                    case .success(let token):
                        self?.requestVerificationCode(captchaToken: token)
                    default:
                        self?.resendButton.isBusy = false
                    }
                }
            case let .failure(error):
                reporter.report(error: error)
                weakSelf.alert(error.localizedDescription)
                weakSelf.resendButton.isBusy = false
            }
        }
    }
    
    func login() {
        isBusy = true
        let key = Ed25519PrivateKey()
        let code = verificationCodeField.text
        let registrationId = Int(SignalProtocol.shared.getRegistrationId())
        login(code: code, registrationId: registrationId, key: key)
    }
    
    func login(code: String, registrationId: Int, key: Ed25519PrivateKey) {
        let sessionSecret = key.publicKey.rawRepresentation.base64EncodedString()
        let request = AccountRequest(code: code,
                                     registrationId: registrationId,
                                     pin: nil,
                                     sessionSecret: sessionSecret)
        AccountAPI.login(verificationId: context.verificationId, accountRequest: request, completion: { [weak self] (result) in
            DispatchQueue.global().async {
                self?.handleLoginResult(result, key: key)
            }
        })
    }
    
    func handleLoginResult(_ result: MixinAPI.Result<Account>, key: Ed25519PrivateKey) {
        switch result {
        case let .success(account):
            guard !account.pin_token.isEmpty, let remotePublicKey = Data(base64Encoded: account.pin_token), let pinToken = AgreementCalculator.agreement(fromPublicKeyData: remotePublicKey, privateKeyData: key.x25519Representation) else {
                DispatchQueue.main.async {
                    self.handleVerificationCodeError(.invalidServerPinToken)
                }
                return
            }
            AppGroupKeychain.sessionSecret = key.rfc8032Representation
            AppGroupKeychain.pinToken = pinToken
            LoginManager.shared.setAccount(account, updateUserTable: false)
            if AppGroupUserDefaults.User.localVersion == AppGroupUserDefaults.User.uninitializedVersion {
                AppGroupUserDefaults.migrateUserSpecificDefaults()
            }
            AppGroupContainer.migrateIfNeeded()
            
            TaskDatabase.reloadCurrent()
            UserDatabase.reloadCurrent()
            if AppGroupUserDefaults.User.isLogoutByServer {
                UserDatabase.current.clearSentSenderKey()
                AppGroupUserDefaults.Database.isSentSenderKeyCleared = true
            }
            
            if AppGroupUserDefaults.User.localVersion == AppGroupUserDefaults.User.uninitializedVersion {
                AppGroupUserDefaults.User.localVersion = AppGroupUserDefaults.User.version
            }
            
            if account.full_name.isEmpty {
                reporter.report(event: .signUp)
            } else if HomeViewController.showChangePhoneNumberTips {
                reporter.report(event: .login, userInfo: ["source": "emergency"])
            } else {
                reporter.report(event: .login, userInfo: ["source": "normal"])
            }
            
            logBackup()
            
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
                        ContactAPI.syncContacts()
                        AppDelegate.current.mainWindow.rootViewController = makeInitialViewController()
                    }
                }
            } else {
                DispatchQueue.main.sync {
                    AppGroupUserDefaults.Account.canRestoreChat = true
                    AppDelegate.current.mainWindow.rootViewController = makeInitialViewController()
                }
            }
            UIApplication.shared.setShortcutItemsEnabled(true)
        case let .failure(error):
            DispatchQueue.main.sync {
                self.handleVerificationCodeError(error)
            }
        }
    }
    
    private func logBackup() {
        guard let icloudDir = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            return
        }
        
        var logs = [String]()
        logs.append("[iCloud]...isLogoutByServer:\(AppGroupUserDefaults.User.isLogoutByServer)")
        if let backupDir = backupUrl {
            let backupExist = backupDir.appendingPathComponent(backupDatabaseName).isStoredCloud
            let fileSize = backupDir.appendingPathComponent(backupDatabaseName).fileSize
            logs.append("[iCloud][\(backupDatabaseName)]...backupExist:\(backupExist)...fileSize:\(fileSize.sizeRepresentation())")
        }
        logs += debugCloudFiles(baseDir: icloudDir, parentDir: icloudDir)
        Logger.write(log: logs.joined(separator: "\n"), newSection: true)
    }
    
    
    private func debugCloudFiles(baseDir: URL, parentDir: URL) -> [String] {
        let files = FileManager.default.childFiles(parentDir)
        var dirs = [String]()
        
        for file in files {
            let url = parentDir.appendingPathComponent(file)
            if FileManager.default.directoryExists(atPath: url.path) {
                dirs.append("[iCloud][\(url.suffix(base: baseDir))] \(files.count) child files")
                dirs += debugCloudFiles(baseDir: baseDir, parentDir: url)
            } else if file.contains("mixin.db") {
                dirs.append("[iCloud][\(url.suffix(base: baseDir))] file size:\(url.fileSize.sizeRepresentation())")
            }
        }
        
        return dirs
    }
    
}
