import UIKit
import MixinServices

protocol LoginAccountHandler {
    func login(account: Account, sessionKey: Ed25519PrivateKey) -> MixinAPIError?
}

extension LoginAccountHandler where Self: UIViewController {
    
    func login(account: Account, sessionKey: Ed25519PrivateKey) -> MixinAPIError? {
        guard
            !account.pinToken.isEmpty,
            let remotePublicKey = Data(base64Encoded: account.pinToken),
            let pinToken = AgreementCalculator.agreement(
                publicKey: remotePublicKey,
                privateKey: sessionKey.x25519Representation
            )
        else {
            return .invalidServerPinToken
        }
        AppGroupKeychain.sessionSecret = sessionKey.rawRepresentation
        AppGroupKeychain.pinToken = pinToken
        if !account.isAnonymous {
            // That's for mnemonic-based users. Should be cleared after phone number users log in to avoid confusion.
            AppGroupKeychain.mnemonics = nil
            Logger.general.info(category: "Login", message: "AppGroupKeychain.mnemonics cleared")
        }
        LoginManager.shared.setAccount(account, updateUserTable: false)
        if AppGroupUserDefaults.User.localVersion == AppGroupUserDefaults.User.uninitializedVersion {
            AppGroupUserDefaults.migrateUserSpecificDefaults()
        }
        AppGroupContainer.migrateIfNeeded()
        
        TaskDatabase.reloadCurrent()
        UserDatabase.reloadCurrent()
        
        if AppGroupUserDefaults.User.localVersion == AppGroupUserDefaults.User.uninitializedVersion {
            AppGroupUserDefaults.User.localVersion = AppGroupUserDefaults.User.version
        }
        AppGroupUserDefaults.User.isTIPInitialized = false
        
        if account.fullName.isEmpty {
            reporter.report(event: .signUp)
        } else if HomeViewController.showChangePhoneNumberTips {
            reporter.report(event: .login, userInfo: ["source": "emergency"])
        } else {
            reporter.report(event: .login, userInfo: ["source": "normal"])
        }
        
        if let icloudDir = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            
            func debugCloudFiles(baseDir: URL, parentDir: URL) -> [String] {
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
            
            var logs = [String]()
            if let backupDir = backupUrl {
                let backupExist = backupDir.appendingPathComponent(backupDatabaseName).isStoredCloud
                let fileSize = backupDir.appendingPathComponent(backupDatabaseName).fileSize
                logs.append("[iCloud][\(backupDatabaseName)]...backupExist:\(backupExist)...fileSize:\(fileSize.sizeRepresentation())")
            }
            logs += debugCloudFiles(baseDir: icloudDir, parentDir: icloudDir)
            Logger.general.info(category: "LoginRestore", message: logs.joined(separator: "\n"))
        }
        
        UserDAO.shared.updateAccount(account: account)
        OutputDAO.shared.deleteAll()
        RawTransactionDAO.shared.deleteAll()
        TokenExtraDAO.shared.nullifyAllBalances()
        
        if account.fullName.isEmpty {
            let vc = UsernameViewController()
            self.navigationController?.pushViewController(vc, animated: true)
        } else {
            AppGroupUserDefaults.Account.canRestoreFromPhone = true
            let restore = RestoreChatViewController()
            let navigationController = UINavigationController(rootViewController: restore)
            navigationController.navigationBar.standardAppearance = .general
            navigationController.navigationBar.scrollEdgeAppearance = .general
            navigationController.navigationBar.tintColor = R.color.icon_tint()
            AppDelegate.current.mainWindow.rootViewController = navigationController
        }
        
        UIApplication.shared.setShortcutItemsEnabled(true)
        return nil
    }
    
}
