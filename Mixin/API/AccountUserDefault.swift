import Foundation
import KeychainAccess

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
        Keychain.removePinToken()
    }

    func storeToken(token: String) {
        session.setValue(token, forKey: keySessionSecret)
        session.synchronize()
        Keychain.removeToken()
    }

    func getPinToken(callback: @escaping (String?) -> Void) {
        if let pinToken = getPinToken() {
            callback(pinToken)
        } else {
            AccountAPI.shared.getPinToken(completion: { (result) in
                guard let sessionId = AccountAPI.shared.account?.session_id, let token = AccountUserDefault.shared.getToken(), !token.isEmpty else {
                    callback(nil)
                    return
                }
                switch result {
                case let .success(response):
                    let pinToken = KeyUtil.rsaDecrypt(pkString: token, sessionId: sessionId, pinToken: response.pinToken)
                    AccountUserDefault.shared.storePinToken(pinToken: pinToken)
                    callback(pinToken)
                case .failure:
                    callback(nil)
                }
            })
        }
    }

    func upgrade() {
        guard AccountAPI.shared.account != nil else {
            Keychain.removePinToken()
            Keychain.removeToken()
            return
        }
        if let token = Keychain.getToken(), !token.isEmpty {
            storeToken(token: token)
        }
        if let pinToken = Keychain.getPinToken(), !pinToken.isEmpty {
            storePinToken(pinToken: pinToken)
        }
    }

    func clear() {
        if let appDomain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: appDomain)
            UserDefaults.standard.synchronize()
        }
        Keychain.removeToken()
        Keychain.removePinToken()
    }
}
