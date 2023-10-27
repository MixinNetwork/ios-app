import MixinServices
import Alamofire

public final class AccountAPI: MixinAPI {
    
    public enum LogCategory {
        case incorrectPin
        case all
    }
    
    enum Path {
        static let verifications = "/verifications"
        static func verifications(id: String) -> String {
            return "/verifications/\(id)"
        }
        static let logout = "/logout"
        static let preferences = "/me/preferences"
        
        static let session = "/session"
        static let sessionSecret = "/session/secret"
        
        static let verifyPin = "/pin/verify"
        static let updatePin = "/pin/update"
        
        static let deactivate = "/me/deactivate"
        
        static func logs(offset: String? = nil, category: LogCategory, limit: Int? = nil) -> String {
            var params = [String]()
            if let offset = offset {
                params.append("offset=\(offset)")
            }
            switch category {
            case .incorrectPin:
                params.append("category=PIN_INCORRECT")
            case .all:
                break
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
    
    public enum VoIPToken {
        
        case token(String)
        case remove
        
        var value: String {
            switch self {
            case .token(let value):
                return value
            case .remove:
                return "REMOVE"
            }
        }
        
    }
    
    public static func me(completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        request(method: .get, path: "/safe/me", completion: completion)
    }
    
    public static func me() async throws -> Account {
        try await withCheckedThrowingContinuation { continuation in
            me(completion: continuation.resume(with:))
        }
    }
    
    @discardableResult
    public static func sendCode(to phoneNumber: String, captchaToken: CaptchaToken?, purpose: VerificationPurpose, completion: @escaping (MixinAPI.Result<VerificationResponse>) -> Void) -> Request? {
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
        return request(method: .post, path: Path.verifications, parameters: param, options: .authIndependent, completion: completion)
    }
    
    public static func login(verificationId: String, accountRequest: AccountRequest, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        request(method: .post, path: Path.verifications(id: verificationId), parameters: accountRequest, options: .authIndependent, completion: completion)
    }
    
    public static func changePhoneNumber(verificationID: String, code: String, pin: String, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        PINEncryptor.encrypt(pin: pin, tipBody: {
            try TIPBody.updatePhoneNumber(verificationID: verificationID, code: code)
        }, onFailure: completion) { pin in
            let accountRequest = AccountRequest(code: code, registrationId: nil, pin: pin, sessionSecret: nil)
            self.request(method: .post,
                         path: Path.verifications(id: verificationID),
                         parameters: accountRequest,
                         options: .disableRetryOnRequestSigningTimeout,
                         completion: completion)
        }
    }
    
    public static func update(fullName: String? = nil, biography: String? = nil, avatarBase64: String? = nil, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
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
        request(method: .post, path: "/me", parameters: param, completion: completion)
    }
    
    public static func updateSession(deviceToken: String? = nil, voipToken: VoIPToken? = nil, deviceCheckToken: String? = nil) {
        let sessionRequest = SessionRequest(notification_token: deviceToken ?? "", voip_token: voipToken?.value ?? "", device_check_token: deviceCheckToken ?? "")
        request(method: .post, path: Path.session, parameters: sessionRequest) { (result: MixinAPI.Result<Account>) in
            
        }
    }
    
    public static func update(sessionSecret: String) -> MixinAPI.Result<SessionSecretUpdateResponse> {
        let param = ["session_secret": sessionSecret]
        return request(method: .post,
                       path: Path.sessionSecret,
                       parameters: param)
    }
    
    public static func preferences(preferenceRequest: UserPreferenceRequest, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        request(method: .post, path: Path.preferences, parameters: preferenceRequest, completion: completion)
    }
    
    public static func verify(pin: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        let timestamp = UInt64(Date().timeIntervalSince1970) * UInt64(NSEC_PER_SEC)
        PINEncryptor.encrypt(pin: pin, tipBody: {
            try TIPBody.verify(timestamp: timestamp)
        }, onFailure: completion) { (encryptedPin) in
            self.request(method: .post,
                         path: Path.verifyPin,
                         parameters: ["pin_base64": encryptedPin, "timestamp": timestamp],
                         options: .disableRetryOnRequestSigningTimeout,
                         completion: completion)
        }
    }
    
    public static func updatePINWithoutTIP(old: String?, new: String, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        func encryptNewPinThenStartRequest() {
            PINEncryptor.encrypt(pin: new, tipBody: {
                throw PINEncryptor.Error.legacyPINAfterTIPSet
            }, onFailure: completion) { encryptedPin in
                param["pin_base64"] = encryptedPin
                request(method: .post, path: Path.updatePin, parameters: param, options: .disableRetryOnRequestSigningTimeout, completion: completion)
            }
        }
        var param: [String: String] = [:]
        if let old = old {
            PINEncryptor.encrypt(pin: old, tipBody: {
                throw PINEncryptor.Error.legacyPINAfterTIPSet
            }, onFailure: completion) { encryptedPin in
                param["old_pin_base64"] = encryptedPin
                encryptNewPinThenStartRequest()
            }
        } else {
            encryptNewPinThenStartRequest()
        }
    }
    
    static func updatePIN(request pinRequest: PINRequest) async throws -> Account {
        try await withCheckedThrowingContinuation { continuation in
            request(method: .post, path: Path.updatePin, parameters: pinRequest, options: .disableRetryOnRequestSigningTimeout) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public static func logs(offset: String? = nil, category: LogCategory, limit: Int? = nil, completion: @escaping (MixinAPI.Result<[LogResponse]>) -> Void) {
        request(method: .get, path: Path.logs(offset: offset, category: category, limit: limit), completion: completion)
    }
    
    public static func logoutSession(sessionId: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        request(method: .post, path: Path.logout, parameters: ["session_id": sessionId], completion: completion)
    }
    
    public static func deactiveVerification(verificationId: String, code: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        let parameters = ["code": code, "purpose": VerificationPurpose.deactivated.rawValue]
        request(method: .post,
                path: Path.verifications(id: verificationId),
                parameters: parameters,
                options: .disableRetryOnRequestSigningTimeout,
                completion: completion)
    }
    
    public static func deactiveAccount(pin: String, verificationID: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        PINEncryptor.encrypt(pin: pin, tipBody: {
            try TIPBody.deactivateUser(phoneVerificationID: verificationID)
        }, onFailure: completion) { (encryptedPin) in
            let parameters = ["pin_base64": encryptedPin, "verification_id": verificationID]
            request(method: .post,
                    path: Path.deactivate,
                    parameters: parameters,
                    options: .disableRetryOnRequestSigningTimeout,
                    completion: completion)
        }
    }

}
