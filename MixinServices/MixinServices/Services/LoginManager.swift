import Foundation
import Intents

public var myUserId: String {
    LoginManager.shared.account?.userID ?? ""
}

public var myIdentityNumber: String {
    LoginManager.shared.account?.identityNumber ?? "00000"
}

public var myFullname: String {
    LoginManager.shared.account?.fullName ?? ""
}

public final class LoginManager {
    
    public static let shared = LoginManager()
    public static let accountDidChangeNotification = Notification.Name("one.mixin.services.account.did.change")
    public static let didLogoutNotification = Notification.Name("one.mixin.services.did.logout")

    public var inDeviceTransfer = false
    public var loggedOutInDeviceTransfer = false
    
    fileprivate var _account: Account?
    fileprivate var _isLoggedIn = false
    fileprivate var lock = pthread_rwlock_t()

    public var isLoggedIn: Bool {
        pthread_rwlock_rdlock(&lock)
        let loggedIn = _isLoggedIn
        pthread_rwlock_unlock(&lock)
        return loggedIn
    }
    
    public var account: Account? {
        pthread_rwlock_rdlock(&lock)
        let account = _account
        pthread_rwlock_unlock(&lock)
        return account
    }
    
    private var hasValidSessionSecret: Bool {
        AppGroupKeychain.sessionSecret != nil
    }
    
    private init() {
        pthread_rwlock_init(&lock, nil)
        _account = LoginManager.getAccountFromUserDefaults()
        _isLoggedIn = _account != nil && hasValidSessionSecret
        
        if !isAppExtension && _account != nil && !_isLoggedIn {
            DispatchQueue.global().async {
                LoginManager.shared.logout(reason: "No valid account")
            }
        }
    }

    fileprivate static func getAccountFromUserDefaults() -> Account? {
        guard let data = AppGroupUserDefaults.Account.serializedAccount else {
            return nil
        }

        return try? JSONDecoder.default.decode(Account.self, from: data)
    }

    public func reloadAccountFromUserDefaults() {
        pthread_rwlock_wrlock(&lock)
        _account = LoginManager.getAccountFromUserDefaults()
        _isLoggedIn = _account != nil && hasValidSessionSecret
        pthread_rwlock_unlock(&lock)
    }
    
    public func setAccount(_ account: Account?, updateUserTable: Bool = true) {
        pthread_rwlock_wrlock(&lock)
        _account = account
        _isLoggedIn = _account != nil && hasValidSessionSecret
        pthread_rwlock_unlock(&lock)

        if let account = account {
            if let data = try? JSONEncoder.default.encode(account) {
                AppGroupUserDefaults.Account.serializedAccount = data
            }
            NotificationCenter.default.post(onMainThread: LoginManager.accountDidChangeNotification, object: self)
            if updateUserTable {
                DispatchQueue.global().async {
                    UserDAO.shared.updateAccount(account: account)
                }
            }
        } else {
            AppGroupUserDefaults.Account.serializedAccount = nil
        }
    }
    
    public func logout(reason: String) {
        guard !inDeviceTransfer else {
            loggedOutInDeviceTransfer = true
            WebSocketService.shared.disconnect()
            return
        }
        guard let sessionID = account?.sessionID else {
            return
        }

        Logger.general.error(category: "LoginManager", message: "Logout because: \(reason), isAppExtension: \(isAppExtension)")

        pthread_rwlock_wrlock(&lock)
        _account = nil
        _isLoggedIn = false
        pthread_rwlock_unlock(&lock)

        if !isAppExtension {
            AppGroupUserDefaults.Account.serializedAccount = nil
            AppGroupUserDefaults.Wallet.payWithBiometricAuthentication = false
            Queue.main.autoSync {
                INInteraction.deleteAll(completion: nil)
                UserDatabase.current.clearSentSenderKey(sessionID: sessionID)
                Keychain.shared.clearPIN()
                WebSocketService.shared.disconnect()
                AppGroupUserDefaults.Account.clearAll()
                AppGroupKeychain.removeItemsForCurrentSession()
                RequestSigning.removeCachedKey()
                SignalDatabase.current.erase()
                PropertiesDAO.shared.removeValue(forKey: .iterator)
                AppGroupUserDefaults.Crypto.clearAll()
                ReceiveMessageService.shared.updatePendingMessageStatuses { statuses in
                    statuses.removeAll()
                }
                NotificationCenter.default.post(name: LoginManager.didLogoutNotification, object: self)
            }
        }
    }
    
}
