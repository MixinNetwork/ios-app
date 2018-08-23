import Foundation

class AccountUserDefault {

    private let keyAccount = "Account"
    private let keySessionSecret = "session_secret"
    private let keyPinToken = "pin_token"


    static let shared = AccountUserDefault()

    private let session = UserDefaults.standard

    func storeAccount(account: Account?) {
        if let account = account {
            if let data = try? JSONEncoder().encode(account) {
                session.setValue(data, forKey: keyAccount)
            }
        } else {
            session.removeObject(forKey: keyAccount)
        }
        session.synchronize()
        NotificationCenter.default.post(name: .AccountDidChange, object: nil)
    }

    func getAccount() -> Account? {
        guard let data = session.value(forKey: keyAccount) as? Data, let account = try? JSONDecoder().decode(Account.self, from: data) else {
            return nil
        }
        return account
    }

    func getToken() -> String? {
        return session.string(forKey: keySessionSecret)
    }

    func getPinToken() -> String? {
        return session.string(forKey: keyPinToken)
    }

    func storePinToken(pinToken: String) {
        session.setValue(pinToken, forKey: keyPinToken)
        session.synchronize()
    }

    func storeToken(token: String) {
        session.setValue(token, forKey: keySessionSecret)
        session.synchronize()
    }

    func clear() {
        if let appDomain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: appDomain)
            UserDefaults.standard.synchronize()
        }
    }
}
