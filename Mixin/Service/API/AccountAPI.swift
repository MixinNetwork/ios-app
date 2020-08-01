import MixinServices
import Alamofire

final class AccountAPI: MixinAPI {
    
    static let shared = AccountAPI()
    
    private let avatarJPEGCompressionQuality: CGFloat = 0.8
    
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
		static func logs(offset: String? = nil, category: String? = nil, limit: Int? = nil) -> String {
            var url = "logs"
            if let offset = offset {
                url += "?offset=\(offset)"
            }
            if let category = category {
                url += (url.contains("?") ? "&" : "?") + "category=\(category)"
            }
            if let limit = limit {
                url += (url.contains("?") ? "&" : "?") + "limit=\(limit)"
            }
            return url
        }

        static let sessions = "sessions/fetch"
    }

    func me(completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        request(method: .get, url: url.me, completion: completion)
    }

    @discardableResult
    func sendCode(to phoneNumber: String, reCaptchaToken: String?, purpose: VerificationPurpose, completion: @escaping (MixinAPI.Result<VerificationResponse>) -> Void) -> Request? {
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
    
    func login(verificationId: String, accountRequest: AccountRequest, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        request(method: .post, url: url.verifications(id: verificationId), parameters: accountRequest.toParameters(), encoding: EncodableParameterEncoding<AccountRequest>(), checkLogin: false, completion: completion)
    }
    
    func changePhoneNumber(verificationId: String, accountRequest: AccountRequest, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        let pin = accountRequest.pin!
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { [weak self](encryptedPin) in
            var parameters = accountRequest
            parameters.pin = encryptedPin
            self?.request(method: .post, url: url.verifications(id: verificationId), parameters: parameters.toParameters(), encoding: EncodableParameterEncoding<AccountRequest>(), completion: completion)
        }
    }
    
    func update(fullName: String? = nil, biography: String? = nil, avatarBase64: String? = nil, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
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
        request(method: .post, url: url.session, parameters: sessionRequest.toParameters(), encoding: EncodableParameterEncoding<SessionRequest>()) { (result: MixinAPI.Result<Account>) in

        }
    }

    func getSessions(userIds: [String], completion: @escaping (MixinAPI.Result<[UserSession]>) -> Void) {
        request(method: .post, url: url.sessions, parameters: userIds.toParameters(), encoding: JSONArrayEncoding(), completion: completion)
    }
    
    func preferences(preferenceRequest: UserPreferenceRequest, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        request(method: .post, url: url.preferences, parameters: preferenceRequest.toParameters(), encoding: EncodableParameterEncoding<UserPreferenceRequest>(), completion: completion)
    }

    func verify(pin: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { [weak self](encryptedPin) in
            self?.request(method: .post, url: url.verifyPin, parameters: ["pin": encryptedPin], completion: completion)
        }
    }
    
    func updatePin(old: String?, new: String, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        guard let pinToken = AppGroupUserDefaults.Account.pinToken else {
            completion(.failure(APIError(status: 200, code: 400, description: MixinServices.Localized.TOAST_OPERATION_FAILED)))
            return
        }
        var param: [String: String] = [:]
        if let old = old {
            guard let encryptedOldPin = KeyUtil.aesEncrypt(pinToken: pinToken, pin: old) else {
                completion(.failure(APIError(status: 200, code: 400, description: MixinServices.Localized.TOAST_OPERATION_FAILED)))
                return
            }
            param["old_pin"] = encryptedOldPin
        }
        guard let encryptedNewPin = KeyUtil.aesEncrypt(pinToken: pinToken, pin: new) else {
            completion(.failure(APIError(status: 200, code: 400, description: MixinServices.Localized.TOAST_OPERATION_FAILED)))
            return
        }
        param["pin"] = encryptedNewPin
        request(method: .post, url: url.updatePin, parameters: param, completion: completion)
    }

    func logs(offset: String? = nil, category: String? = nil, limit: Int? = nil, completion: @escaping (MixinAPI.Result<[LogResponse]>) -> Void) {
        request(method: .get, url: url.logs(offset: offset, category: category, limit: limit), completion: completion)
    }

    func logoutSession(sessionId: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        request(method: .post, url: url.logout, parameters: ["session_id": sessionId], completion: completion)
    }
    
}
