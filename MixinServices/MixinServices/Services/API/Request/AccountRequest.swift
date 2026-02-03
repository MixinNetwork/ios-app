import Foundation

public enum VerificationRequest {
    
    private static let generalValues = [
        "platform": "iOS",
        "platform_version": UIDevice.current.systemVersion,
        "app_version": Bundle.main.shortVersionString,
        "package_name": Bundle.main.bundleIdentifier ?? "",
    ]
    
}

extension VerificationRequest {
    
    public static func session(
        phone: String,
        captchaToken: CaptchaToken?
    ) -> [String: Any] {
        var values: [String: Any] = generalValues
        values["purpose"] = VerificationPurpose.session.rawValue
        values["phone"] = phone
        if let pairs = captchaToken?.asVerificationParameters() {
            values.merge(pairs) { (current, _) in current }
        }
        return values
    }
    
    public static func session(
        code: String,
        registrationID: Int,
        sessionSecret: String
    ) -> [String: Any] {
        var values: [String: Any] = generalValues
        values["purpose"] = VerificationPurpose.session.rawValue
        values["code"] = code
        values["registration_id"] = registrationID
        values["session_secret"] = sessionSecret
        return values
    }
    
}

extension VerificationRequest {
    
    public static func anonymousSession(
        publicKey: Data,
        message: Data,
        signature: Data,
        captchaToken: CaptchaToken?
    ) -> [String: Any] {
        var values: [String: Any] = generalValues
        values["purpose"] = VerificationPurpose.anonymousSession.rawValue
        values["master_public_hex"] = publicKey.hexEncodedString()
        values["master_message_hex"] = message.hexEncodedString()
        values["master_signature_hex"] = signature.hexEncodedString()
        if let pairs = captchaToken?.asVerificationParameters() {
            values.merge(pairs) { (current, _) in current }
        }
        return values
    }
    
    public static func anonymousSession(
        masterSignature: Data,
        registrationID: Int,
        sessionSecret: Data
    ) -> [String: Any] {
        var values: [String: Any] = generalValues
        values["purpose"] = VerificationPurpose.anonymousSession.rawValue
        values["master_signature_hex"] = masterSignature.hexEncodedString()
        values["registration_id"] = registrationID
        values["session_secret"] = sessionSecret.base64EncodedString()
        return values
    }
    
}

extension VerificationRequest {
    
    public static func verifyPhoneNumber(
        phone: String,
        purpose: VerificationPurpose,
        base64Salt: String,
        captchaToken: CaptchaToken?
    ) -> [String: Any] {
        var values: [String: Any] = generalValues
        values["purpose"] = purpose.rawValue
        values["phone"] = phone
        values["salt_base64"] = base64Salt
        if let pairs = captchaToken?.asVerificationParameters() {
            values.merge(pairs) { (current, _) in current }
        }
        return values
    }
    
}

extension VerificationRequest {
    
    public static func deactivate(
        phoneNumber: String,
        captchaToken: CaptchaToken?
    ) -> [String: Any] {
        var values: [String: Any] = generalValues
        values["purpose"] = VerificationPurpose.deactivate.rawValue
        values["phone"] = phoneNumber
        if let pairs = captchaToken?.asVerificationParameters() {
            values.merge(pairs) { (current, _) in current }
        }
        return values
    }
    
    public static func deactivate(
        code: String
    ) -> [String: Any] {
        var values: [String: Any] = generalValues
        values["purpose"] = VerificationPurpose.deactivate.rawValue
        values["code"] = code
        return values
    }
    
}
