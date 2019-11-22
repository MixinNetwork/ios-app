import Foundation
import Alamofire
import UserNotifications

final class AccountAPI: BaseAPI {
    
    static let shared = AccountAPI()
    
    private let avatarJPEGCompressionQuality: CGFloat = 0.8
    private let accountStorageKey = "Account"
    
    enum url {
        static let verifications = "verifications"
        static func verifications(id: String) -> String {
            return "verifications/\(id)"
        }
        static let me = "me"
        static let logout = "logout"
        static let preferences = "me/preferences"

        static let session = "session"

        static let verifyPin = "pin/verify"
        static let updatePin = "pin/update"
        static func pinLogs(offset: String? = nil) -> String {
            var url = "pin_logs"
            if let offset = offset {
                url += "?offset=\(offset)"
            }
            return url
        }

        static let sessions = "sessions/fetch"
    }
    
    private lazy var jsonEncoder = JSONEncoder()
    
    var didLogin: Bool {
        guard account != nil else {
            return false
        }
        guard let token = AppGroupUserDefaults.Account.sessionSecret, !token.isEmpty else {
            return false
        }
        return true
    }

    var accountUserId: String {
        return account?.user_id ?? ""
    }

    var accountSessionId: String {
        return account?.session_id ?? ""
    }

    var accountIdentityNumber: String {
        return account?.identity_number ?? "00000"
    }
    
    // FIXME: Extend AppGroupUserDefaults for account r/w
    var account: Account? = {
        guard let data = AppGroupUserDefaults.Account.serializedAccount else {
            return nil
        }
        return try? JSONDecoder.default.decode(Account.self, from: data)
    }()
    
    // FIXME: Extend AppGroupUserDefaults for account r/w
    func updateAccount(account: Account) {
        self.account = account
        if let data = try? JSONEncoder.default.encode(account) {
            AppGroupUserDefaults.Account.serializedAccount = data
        }
        NotificationCenter.default.post(name: .AccountDidChange, object: nil)
        DispatchQueue.global().async {
            UserDAO.shared.updateAccount(account: account)
        }
    }

    func me() -> APIResult<Account> {
        return request(method: .get, url: url.me)
    }

    func me(completion: @escaping (APIResult<Account>) -> Void) {
        request(method: .get, url: url.me, completion: completion)
    }

    @discardableResult
    func sendCode(to phoneNumber: String, reCaptchaToken: String?, purpose: VerificationPurpose, completion: @escaping (APIResult<VerificationResponse>) -> Void) -> Request? {
        var param = ["phone": phoneNumber,
                     "purpose": purpose.rawValue]
        if let token = reCaptchaToken {
            param["g_recaptcha_response"] = token
        }
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            param["package_name"] = bundleIdentifier
        }
        return request(method: .post, url: url.verifications, parameters: param, checkLogin: false, completion: completion)
    }
    
    func login(verificationId: String, accountRequest: AccountRequest, completion: @escaping (APIResult<Account>) -> Void) {
        request(method: .post, url: url.verifications(id: verificationId), parameters: accountRequest.toParameters(), encoding: EncodableParameterEncoding<AccountRequest>(), checkLogin: false, completion: completion)
    }
    
    func changePhoneNumber(verificationId: String, accountRequest: AccountRequest, completion: @escaping (APIResult<Account>) -> Void) {
        let pin = accountRequest.pin!
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { [weak self](encryptedPin) in
            var parameters = accountRequest
            parameters.pin = encryptedPin
            self?.request(method: .post, url: url.verifications(id: verificationId), parameters: parameters.toParameters(), encoding: EncodableParameterEncoding<AccountRequest>(), completion: completion)
        }
    }
    
    func update(fullName: String? = nil, biography: String? = nil, avatarBase64: String? = nil, completion: @escaping (APIResult<Account>) -> Void) {
        guard fullName != nil || avatarBase64 != nil || biography != nil else {
            assertionFailure("nothing to update")
            return
        }
        var param = [String: String]()
        if let fullName = fullName {
            param["full_name"] = fullName
        }
        if let biography = biography {
            param["biography"] = biography
        }
        if let avatarBase64 = avatarBase64 {
            param["avatar_base64"] = avatarBase64
        }
        request(method: .post, url: url.me, parameters: param, completion: completion)
    }

    func updateSession(deviceToken: String? = nil, voipToken: String? = nil, deviceCheckToken: String? = nil) {
        let sessionRequest = SessionRequest(notification_token: deviceToken ?? "", voip_token: voipToken ?? "", device_check_token: deviceCheckToken ?? "")
        request(method: .post, url: url.session, parameters: sessionRequest.toParameters(), encoding: EncodableParameterEncoding<SessionRequest>()) { (result: APIResult<Account>) in

        }
    }

    func getSessions(userIds: [String], completion: @escaping (APIResult<[UserSession]>) -> Void) {
        request(method: .post, url: url.sessions, parameters: userIds.toParameters(), encoding: JSONArrayEncoding(), completion: completion)
    }
    
    func preferences(preferenceRequest: UserPreferenceRequest, completion: @escaping (APIResult<Account>) -> Void) {
        request(method: .post, url: url.preferences, parameters: preferenceRequest.toParameters(), encoding: EncodableParameterEncoding<UserPreferenceRequest>(), completion: completion)
    }

    func verify(pin: String, completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { [weak self](encryptedPin) in
            self?.request(method: .post, url: url.verifyPin, parameters: ["pin": encryptedPin], completion: completion)
        }
    }
    
    func updatePin(old: String?, new: String, completion: @escaping (APIResult<Account>) -> Void) {
        guard let pinToken = AppGroupUserDefaults.Account.pinToken else {
            completion(.failure(APIError(status: 200, code: 400, description: Localized.TOAST_OPERATION_FAILED)))
            return
        }
        var param: [String: String] = [:]
        if let old = old {
            guard let encryptedOldPin = KeyUtil.aesEncrypt(pinToken: pinToken, pin: old) else {
                completion(.failure(APIError(status: 200, code: 400, description: Localized.TOAST_OPERATION_FAILED)))
                return
            }
            param["old_pin"] = encryptedOldPin
        }
        guard let encryptedNewPin = KeyUtil.aesEncrypt(pinToken: pinToken, pin: new) else {
            completion(.failure(APIError(status: 200, code: 400, description: Localized.TOAST_OPERATION_FAILED)))
            return
        }
        param["pin"] = encryptedNewPin
        request(method: .post, url: url.updatePin, parameters: param, completion: completion)
    }

    func pinLogs(offset: String? = nil, completion: @escaping (APIResult<[PINLogResponse]>) -> Void) {
        request(method: .get, url: url.pinLogs(offset: offset), completion: completion)
    }

    func logoutSession(sessionId: String, completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        request(method: .post, url: url.logout, parameters: ["session_id": sessionId], completion: completion)
    }
    
    func logout(from: String) {
        guard account != nil else {
            return
        }
        UIApplication.shared.setShortcutItemsEnabled(false)
        Logger.write(log: "===========logout...from:\(from)")
        AppGroupUserDefaults.User.isLogoutByServer = true
        DispatchQueue.main.async {
            self.account = nil
            Keychain.shared.clearPIN()
            WebSocketService.shared.disconnect()
            BackupJobQueue.shared.cancelAllOperations()
            AppGroupUserDefaults.Account.clearAll()
            SignalDatabase.shared.logout()
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = 1
                UIApplication.shared.applicationIconBadgeNumber = 0
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                UIApplication.shared.unregisterForRemoteNotifications()

                MixinWebView.clearCookies()
                let oldRootViewController = AppDelegate.current.window.rootViewController
                AppDelegate.current.window.rootViewController = LoginNavigationController.instance()
                oldRootViewController?.navigationController?.removeFromParent()
            }
        }
    }
}
