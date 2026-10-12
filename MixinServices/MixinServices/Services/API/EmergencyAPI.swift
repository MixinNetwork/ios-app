import MixinServices

public final class EmergencyAPI: MixinAPI {
    
    private enum Path {
        static let create = "/emergency_verifications"
        static let show = "/emergency_contact"
        static let delete = "/emergency_contact/delete"
        static func verify(id: String) -> String {
            "/emergency_verifications/" + id
        }
    }
    
    public static func createContact(
        identityNumber: String,
        completion: @escaping (MixinAPI.Result<EmergencyResponse>) -> Void
    ) {
        let parameters = EmergencyRequest(
            phone: nil,
            identityNumber: identityNumber,
            pin: nil,
            code: nil,
            purpose: .contact
        )
        request(
            method: .post,
            path: Path.create,
            parameters: parameters,
            completion: completion
        )
    }
    
    public static func verifyContact(
        pin: String,
        id: String,
        code: String,
        completion: @escaping (MixinAPI.Result<Account>) -> Void
    ) {
        PINEncryptor.encrypt(pin: pin, tipBody: {
            try TIPBody.createEmergencyContact(verificationID: id, code: code)
        }, onFailure: completion) { (encryptedPin) in
            let parameters = EmergencyRequest(
                phone: nil,
                identityNumber: nil,
                pin: encryptedPin,
                code: code,
                purpose: .contact
            )
            request(
                method: .post,
                path: Path.verify(id: id),
                parameters: parameters,
                options: [.disableRetryOnRequestSigningTimeout],
                completion: completion
            )
        }
    }
    
    public static func createSession(
        phoneNumber: String,
        identityNumber: String,
        completion: @escaping (MixinAPI.Result<EmergencyResponse>) -> Void
    ) {
        let parameters = EmergencyRequest(
            phone: phoneNumber,
            identityNumber: identityNumber,
            pin: nil,
            code: nil,
            purpose: .session
        )
        request(
            method: .post,
            path: Path.create,
            parameters: parameters,
            options: [.authIndependent],
            completion: completion
        )
    }
    
    public static func verifySession(
        id: String,
        code: String,
        sessionSecret: String?,
        registrationId: Int?,
        completion: @escaping (MixinAPI.Result<Account>) -> Void
    ) {
        let parameters = EmergencySessionRequest(
            code: code,
            sessionSecret: sessionSecret,
            registrationId: registrationId
        )
        request(
            method: .post,
            path: Path.verify(id: id),
            parameters: parameters,
            options: [.authIndependent],
            completion: completion
        )
    }
    
    public static func show(
        pin: String,
        completion: @escaping (MixinAPI.Result<User>) -> Void
    ) {
        PINEncryptor.encrypt(pin: pin, tipBody: {
            try TIPBody.readEmergencyContact()
        }, onFailure: completion) { (encryptedPin) in
            let param = ["pin_base64": encryptedPin]
            request(
                method: .post,
                path: Path.show,
                parameters: param,
                options: [.disableRetryOnRequestSigningTimeout],
                completion: completion
            )
        }
    }
    
    public static func delete(
        pin: String,
        completion: @escaping (MixinAPI.Result<Account>) -> Void
    ) {
        PINEncryptor.encrypt(pin: pin, tipBody: {
            try TIPBody.removeEmergencyContact()
        }, onFailure: completion) { (encryptedPin) in
            let param = ["pin_base64": encryptedPin]
            request(
                method: .post,
                path: Path.delete,
                parameters: param,
                options: [.disableRetryOnRequestSigningTimeout],
                completion: completion
            )
        }
    }
    
}
