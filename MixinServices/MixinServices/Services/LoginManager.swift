import Foundation

public var myUserId: String {
    LoginManager.shared.account?.user_id ?? ""
}

public var myIdentityNumber: String {
    LoginManager.shared.account?.identity_number ?? "00000"
}

fileprivate let accountDidChangeDarwinNotificationName = CFNotificationName(rawValue: "one.mixin.services.darwin.account.did.change" as CFString)

public final class LoginManager {
    
    public static let shared = LoginManager()
    public static let accountDidChangeNotification = Notification.Name("one.mixin.services.account.did.change")
    public static let didLogoutNotification = Notification.Name("one.mixin.services.did.logout")
    
    private let darwinNotifyCenter = CFNotificationCenterGetDarwinNotifyCenter()
    
    fileprivate var _account: Account?
    fileprivate var lock = pthread_rwlock_t()
    fileprivate var ignoreNextDarwinNotification = false
    
    private var selfAsOpaquePointer: UnsafeMutableRawPointer {
        Unmanaged.passUnretained(self).toOpaque()
    }
    
    public var isLoggedIn: Bool {
        guard account != nil else {
            return false
        }
        guard let token = AppGroupUserDefaults.Account.sessionSecret, !token.isEmpty else {
            return false
        }
        return true
    }
    
    public var account: Account? {
        pthread_rwlock_rdlock(&lock)
        let account = _account
        pthread_rwlock_unlock(&lock)
        return account
    }
    
    private init() {
        pthread_rwlock_init(&lock, nil)
        _account = LoginManager.getAccountFromUserDefaults()
        CFNotificationCenterAddObserver(darwinNotifyCenter, selfAsOpaquePointer, notificationCallback, accountDidChangeDarwinNotificationName.rawValue, nil, .deliverImmediately)
    }
    
    deinit {
        CFNotificationCenterRemoveEveryObserver(darwinNotifyCenter, selfAsOpaquePointer)
    }
    
    fileprivate static func getAccountFromUserDefaults() -> Account? {
        if let data = AppGroupUserDefaults.Account.serializedAccount {
            return try? JSONDecoder.default.decode(Account.self, from: data)
        } else {
            return nil
        }
    }
    
    public func setAccount(_ account: Account?, updateUserTable: Bool = true) {
        pthread_rwlock_wrlock(&lock)
        _account = account
        pthread_rwlock_unlock(&lock)
        if let account = account {
            if let data = try? JSONEncoder.default.encode(account) {
                AppGroupUserDefaults.Account.serializedAccount = data
            }
            NotificationCenter.default.post(name: LoginManager.accountDidChangeNotification, object: self)
            if updateUserTable {
                DispatchQueue.global().async {
                    UserDAO.shared.updateAccount(account: account)
                }
            }
        } else {
            AppGroupUserDefaults.Account.serializedAccount = nil
        }
        ignoreNextDarwinNotification = true
        CFNotificationCenterPostNotification(darwinNotifyCenter, accountDidChangeDarwinNotificationName, nil, nil, true)
    }
    
    public func logout(from: String) {
        guard account != nil else {
            return
        }
        Logger.write(log: "===========logout...from:\(from)")
        AppGroupUserDefaults.User.isLogoutByServer = true
        DispatchQueue.main.async {
            self.setAccount(nil)
            Keychain.shared.clearPIN()
            WebSocketService.shared.disconnect()
            AppGroupUserDefaults.Account.clearAll()
            SignalDatabase.shared.logout()
            NotificationCenter.default.post(name: LoginManager.didLogoutNotification, object: self)
        }
    }
    
}

fileprivate func notificationCallback(center: CFNotificationCenter?, observer: UnsafeMutableRawPointer?, name: CFNotificationName?, object: UnsafeRawPointer?, userInfo: CFDictionary?) {
    guard let observer = observer else {
        return
    }
    let manager = Unmanaged<LoginManager>.fromOpaque(observer).takeUnretainedValue()
    guard !manager.ignoreNextDarwinNotification else {
        manager.ignoreNextDarwinNotification = false
        return
    }
    let account = LoginManager.getAccountFromUserDefaults()
    pthread_rwlock_wrlock(&manager.lock)
    manager._account = account
    pthread_rwlock_unlock(&manager.lock)
}
