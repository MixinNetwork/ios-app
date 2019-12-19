import Foundation

fileprivate(set) public var myUserId = ""
fileprivate(set) public var myIdentityNumber = "00000"

public var isLoggedIn: Bool {
    guard Account.current != nil else {
        return false
    }
    guard let token = AppGroupUserDefaults.Account.sessionSecret, !token.isEmpty else {
        return false
    }
    return true
}

extension Account {
    
    // TODO: Thread safety?
    public static var current: Account? {
        get {
            return _current
        }
        set {
            _current = newValue
            if let newValue = newValue {
                if let data = try? JSONEncoder.default.encode(newValue) {
                    AppGroupUserDefaults.Account.serializedAccount = data
                }
                NotificationCenter.default.post(name: .AccountDidChange, object: nil)
                DispatchQueue.global().async {
                    UserDAO.shared.updateAccount(account: newValue)
                }
            } else {
                AppGroupUserDefaults.Account.serializedAccount = nil
            }
        }
    }
    
    private static var _current: Account? = {
        if let data = AppGroupUserDefaults.Account.serializedAccount {
            if let account = try? JSONDecoder.default.decode(Account.self, from: data) {
                myUserId = account.user_id
                myIdentityNumber = account.identity_number
                return account
            } else {
                return nil
            }
        } else {
            return nil
        }
    }()
    
}
