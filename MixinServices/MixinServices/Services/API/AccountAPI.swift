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
    public static func sessionVerifications(
        phoneNumber: String,
        captchaToken: CaptchaToken?,
        completion: @escaping (MixinAPI.Result<VerificationResponse>) -> Void
    ) -> Request? {
        let parameters = VerificationRequest.session(
            phone: phoneNumber,
            captchaToken: captchaToken
        )
        return request(
            method: .post,
            path: Path.verifications,
            parameters: parameters,
            options: .authIndependent,
            completion: completion
        )
    }
    
    @discardableResult
    public static func anonymousSessionVerifications(
        publicKey: Data,
        message: Data,
        signature: Data,
        captchaToken: CaptchaToken?,
        completion: @escaping (MixinAPI.Result<VerificationResponse>) -> Void
    ) -> Request? {
        let parameters = VerificationRequest.anonymousSession(
            publicKey: publicKey,
            message: message,
            signature: signature,
            captchaToken: captchaToken
        )
        return request(
            method: .post,
            path: Path.verifications,
            parameters: parameters,
            options: .authIndependent,
            completion: completion
        )
    }
    
    @discardableResult
    public static func phoneVerifications(
        phoneNumber: String,
        purpose: VerificationPurpose,
        base64Salt: String,
        captchaToken: CaptchaToken?,
        completion: @escaping (MixinAPI.Result<VerificationResponse>) -> Void
    ) -> Request? {
        var parameters = VerificationRequest.verifyPhoneNumber(
            phone: phoneNumber,
            purpose: purpose,
            base64Salt: base64Salt,
            captchaToken: captchaToken
        )
        return request(
            method: .post,
            path: Path.verifications,
            parameters: parameters,
            completion: completion
        )
    }
    
    @discardableResult
    public static func deactivateVerifications(
        phoneNumber: String,
        captchaToken: CaptchaToken?,
        completion: @escaping (MixinAPI.Result<VerificationResponse>) -> Void
    ) -> Request? {
        var parameters = VerificationRequest.deactivate(
            phoneNumber: phoneNumber,
            captchaToken: captchaToken
        )
        return request(
            method: .post,
            path: Path.verifications,
            parameters: parameters,
            completion: completion
        )
    }
    
    public static func login(
        verificationId: String,
        code: String,
        registrationID: Int,
        sessionSecret: String,
        completion: @escaping (MixinAPI.Result<Account>) -> Void
    ) {
        let parameters = VerificationRequest.session(
            code: code,
            registrationID: registrationID,
            sessionSecret: sessionSecret
        )
        request(
            method: .post,
            path: Path.verifications(id: verificationId),
            parameters: parameters,
            options: .authIndependent,
            completion: completion
        )
    }
    
    public static func login(
        verificationID: String,
        masterSignature: Data,
        registrationID: Int,
        sessionSecret: Data,
        completion: @escaping (MixinAPI.Result<Account>) -> Void
    ) {
        let parameters = VerificationRequest.anonymousSession(
            masterSignature: masterSignature,
            registrationID: registrationID,
            sessionSecret: sessionSecret
        )
        request(
            method: .post,
            path: Path.verifications(id: verificationID),
            parameters: parameters,
            options: .authIndependent,
            completion: completion
        )
    }
    
    public static func verifyPhoneNumber(
        verificationID: String,
        purpose: VerificationPurpose,
        code: String,
        pin: String,
        salt: String,
        completion: @escaping (MixinAPI.Result<Account>) -> Void
    ) {
        PINEncryptor.encrypt(pin: pin, tipBody: {
            try TIPBody.updatePhoneNumber(verificationID: verificationID, code: code)
        }, onFailure: completion) { pin in
            let parameters = [
                "purpose": purpose.rawValue,
                "code": code,
                "pin": pin,
                "salt_base64": salt,
            ]
            self.request(method: .post,
                         path: Path.verifications(id: verificationID),
                         parameters: parameters,
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
    
    public static func updateSession(
        notificationToken: String? = nil,
        voipToken: VoIPToken? = nil,
        deviceCheckToken: String? = nil,
        completion: ((MixinAPI.Result<Account>) -> Void)?
    ) {
        let sessionRequest = SessionRequest(
            notificationToken: notificationToken,
            voipToken: voipToken?.value,
            deviceCheckToken: deviceCheckToken
        )
        request(method: .post, path: Path.session, parameters: sessionRequest) { result in
            completion?(result)
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
    
    public static func verify(pin: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            verify(pin: pin) { result in
                continuation.resume(with: result)
            }
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
    
    public static func logout(
        sessionID: String,
        pin: String,
        completion: @escaping (MixinAPI.Result<Empty>) -> Void
    ) {
        PINEncryptor.encrypt(pin: pin, tipBody: {
            try TIPBody.logoutSession(sessionID: sessionID)
        }, onFailure: completion) { (encryptedPin) in
            let parameters = [
                "session_id": sessionID,
                "pin_base64": encryptedPin,
            ]
            request(method: .post,
                    path: "/logout",
                    parameters: parameters,
                    options: .disableRetryOnRequestSigningTimeout,
                    completion: completion)
        }
    }
    
    public static func deactiveVerification(
        verificationID: String,
        code: String,
        completion: @escaping (MixinAPI.Result<Empty>) -> Void
    ) {
        request(method: .post,
                path: Path.verifications(id: verificationID),
                parameters: VerificationRequest.deactivate(code: code),
                options: .disableRetryOnRequestSigningTimeout,
                completion: completion)
    }
    
    public static func deactiveAccount(
        pin: String,
        verificationID: String?,
        completion: @escaping (MixinAPI.Result<Empty>) -> Void
    ) {
        PINEncryptor.encrypt(pin: pin, tipBody: {
            if let verificationID {
                try TIPBody.deactivateUser(verificationID: verificationID)
            } else {
                try TIPBody.deactivateUser(userID: myUserId)
            }
        }, onFailure: completion) { (encryptedPin) in
            var parameters = [
                "pin_base64": encryptedPin,
            ]
            if let verificationID {
                parameters["verification_id"] = verificationID
            }
            request(method: .post,
                    path: Path.deactivate,
                    parameters: parameters,
                    options: .disableRetryOnRequestSigningTimeout,
                    completion: completion)
        }
    }
    
    public static func exportSalt(
        pin: String,
        userID: String,
        masterPublicKey: String,
        masterSignature: String,
        completion: @escaping (MixinAPI.Result<Account>) -> Void
    ) {
        PINEncryptor.encrypt(pin: pin, tipBody: {
            try TIPBody.exportPrivate(userID: userID)
        }, onFailure: completion) { (pin) in
            let parameters = [
                "pin_base64": pin,
                "master_public_hex": masterPublicKey,
                "master_signature_hex": masterSignature,
            ]
            request(method: .post,
                    path: "/me/salt_export",
                    parameters: parameters,
                    options: .disableRetryOnRequestSigningTimeout,
                    completion: completion)
        }
    }
    
}
