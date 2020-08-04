import MixinServices

final class EmergencyAPI: MixinAPI {
    
    private enum Url {
        static let create = "emergency_verifications"
        static let show = "emergency_contact"
        static let delete = "emergency_contact/delete"
        static func verify(id: String) -> String {
            return "emergency_verifications/" + id
        }
    }
    
    static func createContact(identityNumber: String, completion: @escaping (MixinAPI.Result<EmergencyResponse>) -> Void) {
        let req = EmergencyRequest(phone: nil,
                                   identityNumber: identityNumber,
                                   pin: nil,
                                   code: nil,
                                   purpose: .contact)
        request(method: .post,
                url: Url.create,
                parameters: req,
                completion: completion)
    }
    
    static func verifyContact(pin: String, id: String, code: String, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { (encryptedPin) in
            let req = EmergencyRequest(phone: nil,
                                       identityNumber: nil,
                                       pin: encryptedPin,
                                       code: code,
                                       purpose: .contact)
            request(method: .post,
                    url: Url.verify(id: id),
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
                url: Url.create,
                parameters: req,
                requiresLogin: false,
                completion: completion)
    }
    
    static func verifySession(id: String, code: String, sessionSecret: String?, registrationId: Int?, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        let req = EmergencySessionRequest(code: code,
                                          sessionSecret: sessionSecret,
                                          registrationId: registrationId)
        request(method: .post,
                url: Url.verify(id: id),
                parameters: req,
                requiresLogin: false,
                completion: completion)
    }
    
    static func show(pin: String, completion: @escaping (MixinAPI.Result<User>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { (encryptedPin) in
            let param = ["pin": encryptedPin]
            request(method: .post, url: Url.show, parameters: param, completion: completion)
        }
    }
    
    static func delete(pin: String, completion: @escaping (MixinAPI.Result<Account>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { (encryptedPin) in
            let param = ["pin": encryptedPin]
            request(method: .post, url: Url.delete, parameters: param, completion: completion)
        }
    }
    
}
