import MixinServices

final class EmergencyAPI: MixinAPI {
    
    private enum Path {
        static let create = "/emergency_verifications"
        static let show = "/emergency_contact"
        static let delete = "/emergency_contact/delete"
        static func verify(id: String) -> String {
            "/emergency_verifications/" + id
        }
    }
    
    static func createContact(identityNumber: String, completion: @escaping (MixinAPI.Result<EmergencyResponse>) -> Void) {
        let req = EmergencyRequest(phone: nil,
                                   identityNumber: identityNumber,
                                   pin: nil,
                                   code: nil,
                                   purpose: .contact)
        request(method: .post,
                path: Path.create,
                parameters: req,
                completion: completion)
    }
    
    static func verifyContact(pin: String, id: String, code: String, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        PINEncryptor.encrypt(pin: pin, onFailure: completion) { (encryptedPin) in
            let req = EmergencyRequest(phone: nil,
                                       identityNumber: nil,
                                       pin: encryptedPin,
                                       code: code,
                                       purpose: .contact)
            request(method: .post,
                    path: Path.verify(id: id),
                    parameters: req,
                    completion: completion)
        }
    }
    
    static func createSession(phoneNumber: String, identityNumber: String, completion: @escaping (MixinAPI.Result<EmergencyResponse>) -> Void) {
        let req = EmergencyRequest(phone: phoneNumber,
                                   identityNumber: identityNumber,
                                   pin: nil,
                                   code: nil,
                                   purpose: .session)
        request(method: .post,
                path: Path.create,
                parameters: req,
                requiresLogin: false,
                completion: completion)
    }
    
    static func verifySession(id: String, code: String, sessionSecret: String?, registrationId: Int?, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        let req = EmergencySessionRequest(code: code,
                                          sessionSecret: sessionSecret,
                                          registrationId: registrationId)
        request(method: .post,
                path: Path.verify(id: id),
                parameters: req,
                requiresLogin: false,
                completion: completion)
    }
    
    static func show(pin: String, completion: @escaping (MixinAPI.Result<User>) -> Void) {
        PINEncryptor.encrypt(pin: pin, onFailure: completion) { (encryptedPin) in
            let param = ["pin": encryptedPin]
            request(method: .post, path: Path.show, parameters: param, completion: completion)
        }
    }
    
    static func delete(pin: String, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        PINEncryptor.encrypt(pin: pin, onFailure: completion) { (encryptedPin) in
            let param = ["pin": encryptedPin]
            request(method: .post, path: Path.delete, parameters: param, completion: completion)
        }
    }
    
}
