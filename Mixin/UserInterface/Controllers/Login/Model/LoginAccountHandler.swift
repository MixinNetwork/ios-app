import UIKit
import WebKit
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
            Logger.login.error(category: "Login", message: "Invalid Server PIN Token")
            return .invalidServerPinToken
        }
        Logger.login.info(category: "Login", message: "Got account: \(account.userID), has_pin: \(account.hasPIN), has_safe: \(account.hasSafe), tip_key: \(account.tipKey?.count ?? -1)")
        AppGroupKeychain.sessionSecret = sessionKey.rawRepresentation
        AppGroupKeychain.pinToken = pinToken
        if !account.isAnonymous {
            // That's for mnemonic-based users. Should be cleared after phone number users log in to avoid confusion.
            AppGroupKeychain.mnemonics = nil
            Logger.login.info(category: "Login", message: "AppGroupKeychain.mnemonics cleared")
        }
        AppGroupKeychain.encryptedTIPPriv = nil
        AppGroupKeychain.ephemeralSeed = nil
        AppGroupKeychain.encryptedSalt = nil
        Keychain.shared.clearPIN()
        Logger.login.info(category: "Login", message: "TIP Secrets cleared")
        LoginManager.shared.setAccount(account, updateUserTable: false)
        
        if AppGroupUserDefaults.User.localVersion == AppGroupUserDefaults.User.uninitializedVersion {
            AppGroupUserDefaults.migrateUserSpecificDefaults()
        }
        AppGroupContainer.migrateIfNeeded()
        
        TaskDatabase.reloadCurrent()
        UserDatabase.reloadCurrent()
        Web3Database.reloadCurrent()
        
        if AppGroupUserDefaults.User.localVersion == AppGroupUserDefaults.User.uninitializedVersion {
            AppGroupUserDefaults.User.localVersion = AppGroupUserDefaults.User.version
        }
        AppGroupUserDefaults.User.loginPINValidated = false
        AppGroupUserDefaults.Wallet.payWithBiometricAuthentication = false
        
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
            Logger.login.info(category: "LoginRestore", message: logs.joined(separator: "\n"))
        }
        
        UserDatabase.current.clearSentSenderKey(sessionID: account.sessionID)
        UserDAO.shared.updateAccount(account: account)
        OutputDAO.shared.deleteAll()
        RawTransactionDAO.shared.deleteAll()
        TokenExtraDAO.shared.nullifyAllBalances()
        Web3DAO.deleteWalletsAddresses()
        WKWebsiteDataStore.default().removeAuthenticationRelatedData()
        
        if !account.fullName.isEmpty {
            AppGroupUserDefaults.Account.canRestoreFromPhone = true
        }
        AppDelegate.current.checkSessionEnvironment(freshAccount: account)
        
        UIApplication.shared.setShortcutItemsEnabled(true)
        return nil
    }
    
}
