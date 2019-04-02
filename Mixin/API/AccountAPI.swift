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

        static let sessions = "sessions/fetch"
    }
    
    private lazy var jsonEncoder = JSONEncoder()
    
    var didLogin: Bool {
        guard account != nil else {
            return false
        }
        guard let token = AccountUserDefault.shared.getToken(), !token.isEmpty else {
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
    
    var account: Account? = AccountUserDefault.shared.getAccount() {
        didSet {
            AccountUserDefault.shared.storeAccount(account: account)
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
    
    func changePhoneNumber(verificationId: String, accountRequest: AccountRequest, completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        let pin = accountRequest.pin!
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { [weak self](encryptedPin) in
            var parameters = accountRequest
            parameters.pin = encryptedPin
            self?.request(method: .post, url: url.verifications(id: verificationId), parameters: parameters.toParameters(), encoding: EncodableParameterEncoding<AccountRequest>(), completion: completion)
        }
    }
    
    func update(fullName: String?, avatarBase64: String? = nil, completion: @escaping (APIResult<Account>) -> Void) {
        guard fullName != nil || avatarBase64 != nil else {
            assertionFailure("nothing to update")
            return
        }
        var param = [String: String]()
        if let fullName = fullName {
            param["full_name"] = fullName
        }
        if let avatarBase64 = avatarBase64 {
            param["avatar_base64"] = avatarBase64
        }
        request(method: .post, url: url.me, parameters: param, completion: completion)
    }

    func updateSession(deviceToken: String, voip_token: String) {
        let sessionRequest = SessionRequest(notification_token: deviceToken, voip_token: voip_token)
        request(method: .post, url: url.session, parameters: sessionRequest.toParameters(), encoding: EncodableParameterEncoding<SessionRequest>()) { (result: APIResult<Account>) in

        }
    }

    func getSessions(userIds: [String], completion: @escaping (APIResult<[UserSession]>) -> Void) {
        request(method: .post, url: url.sessions, parameters: userIds.toParameters(), encoding: JSONArrayEncoding(), completion: completion)
    }
    
    func preferences(userRequest: UserRequest, completion: @escaping (APIResult<UserResponse>) -> Void) {
        request(method: .post, url: url.preferences, parameters: userRequest.toParameters(), encoding: EncodableParameterEncoding<UserRequest>(), completion: completion)
    }

    func verify(pin: String, completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { [weak self](encryptedPin) in
            self?.request(method: .post, url: url.verifyPin, parameters: ["pin": encryptedPin], completion: completion)
        }
    }
    
    func updatePin(old: String?, new: String, completion: @escaping (APIResult<Account>) -> Void) {
        guard let pinToken = AccountUserDefault.shared.getPinToken() else {
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
    
    func logoutSession(sessionId: String, completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        request(method: .post, url: url.logout, parameters: ["session_id": sessionId], completion: completion)
    }
    
    func logout() {
        CommonUserDefault.shared.hasForceLogout = true
        DispatchQueue.main.async {
            self.account = nil
            Keychain.shared.clearPIN()
            WebSocketService.shared.disconnect()
            AccountUserDefault.shared.clear()
            MixinDatabase.shared.logout()
            SignalDatabase.shared.logout(onClosed: {
                UIApplication.shared.applicationIconBadgeNumber = 1
                UIApplication.shared.applicationIconBadgeNumber = 0
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                UIApplication.shared.unregisterForRemoteNotifications()

                MixinWebView.clearCookies()
                let oldRootViewController = AppDelegate.current.window?.rootViewController
                AppDelegate.current.window?.rootViewController = LoginNavigationController.instance()
                oldRootViewController?.navigationController?.removeFromParent()
            })
        }
    }
}
