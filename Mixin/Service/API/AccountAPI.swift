import MixinServices
import Alamofire

final class AccountAPI: MixinAPI {
    
    enum Path {
        static let verifications = "/verifications"
        static func verifications(id: String) -> String {
            return "/verifications/\(id)"
        }
        static let me = "/me"
        static let logout = "/logout"
        static let preferences = "/me/preferences"
        
        static let session = "/session"
        static let sessionSecret = "/session/secret"
        
        static let verifyPin = "/pin/verify"
        static let updatePin = "/pin/update"
        static func logs(offset: String? = nil, category: String? = nil, limit: Int? = nil) -> String {
            var params = [String]()
            if let offset = offset {
                params.append("offset=\(offset)")
            }
            if let category = category {
                params.append("category=\(category)")
            }
            if let limit = limit {
                params.append("limit=\(limit)")
            }
            
            var path = "/logs"
            if !params.isEmpty {
                let query = "?" + params.joined(separator: "&")
                path.append(contentsOf: query)
            }
            return path
        }

    }
    
    static func me(completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        request(method: .get, path: Path.me, completion: completion)
    }
    
    @discardableResult
    static func sendCode(to phoneNumber: String, captchaToken: CaptchaToken?, purpose: VerificationPurpose, completion: @escaping (MixinAPI.Result<VerificationResponse>) -> Void) -> Request? {
        var param = ["phone": phoneNumber,
                     "purpose": purpose.rawValue]
        switch captchaToken {
        case let .reCaptcha(token):
            param["g_recaptcha_response"] = token
        case let .hCaptcha(token):
            param["hcaptcha_response"] = token
        default:
            break
        }
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            param["package_name"] = bundleIdentifier
        }
        return request(method: .post, path: Path.verifications, parameters: param, requiresLogin: false, completion: completion)
    }
    
    static func login(verificationId: String, accountRequest: AccountRequest, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        request(method: .post, path: Path.verifications(id: verificationId), parameters: accountRequest, requiresLogin: false, completion: completion)
    }
    
    static func changePhoneNumber(verificationId: String, accountRequest: AccountRequest, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        let pin = accountRequest.pin!
        PINEncryptor.encrypt(pin: pin, onFailure: completion) { (encryptedPin) in
            var parameters = accountRequest
            parameters.pin = encryptedPin
            self.request(method: .post,
                         path: Path.verifications(id: verificationId),
                         parameters: parameters,
                         completion: completion)
        }
    }
    
    static func update(fullName: String? = nil, biography: String? = nil, avatarBase64: String? = nil, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
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
        request(method: .post, path: Path.me, parameters: param, completion: completion)
    }
    
    static func updateSession(deviceToken: String? = nil, voipToken: String? = nil, deviceCheckToken: String? = nil) {
        let sessionRequest = SessionRequest(notification_token: deviceToken ?? "", voip_token: voipToken ?? "", device_check_token: deviceCheckToken ?? "")
        request(method: .post, path: Path.session, parameters: sessionRequest) { (result: MixinAPI.Result<Account>) in
            
        }
    }
    
    static func update(sessionSecret: String) -> MixinAPI.Result<SessionSecretUpdateResponse> {
        let param = ["session_secret": sessionSecret]
        return request(method: .post,
                       path: Path.sessionSecret,
                       parameters: param)
    }
    
    static func preferences(preferenceRequest: UserPreferenceRequest, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        request(method: .post, path: Path.preferences, parameters: preferenceRequest, completion: completion)
    }
    
    static func verify(pin: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        PINEncryptor.encrypt(pin: pin, onFailure: completion) { (encryptedPin) in
            self.request(method: .post,
                         path: Path.verifyPin,
                         parameters: ["pin": encryptedPin],
                         completion: completion)
        }
    }
    
    static func updatePin(old: String?, new: String, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        var param: [String: String] = [:]
        if let old = old {
            switch PINEncryptor.encrypt(pin: old) {
            case .success(let encryptedOld):
                param["old_pin"] = encryptedOld
            case .failure(let error):
                completion(.failure(.pinEncryption(error)))
                return
            }
        }
        switch PINEncryptor.encrypt(pin: new) {
        case .success(let encryptedNew):
            param["pin"] = encryptedNew
        case .failure(let error):
            completion(.failure(.pinEncryption(error)))
            return
        }
        request(method: .post, path: Path.updatePin, parameters: param, completion: completion)
    }
    
    static func logs(offset: String? = nil, category: String? = nil, limit: Int? = nil, completion: @escaping (MixinAPI.Result<[LogResponse]>) -> Void) {
        request(method: .get, path: Path.logs(offset: offset, category: category, limit: limit), completion: completion)
    }
    
    static func logoutSession(sessionId: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        request(method: .post, path: Path.logout, parameters: ["session_id": sessionId], completion: completion)
    }
    
}
