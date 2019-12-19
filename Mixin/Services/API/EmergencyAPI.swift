import Foundation

public final class EmergencyAPI: BaseAPI {
    
    public static let shared = EmergencyAPI()
    
    private enum Url {
        static let create = "emergency_verifications"
        static let show = "emergency_contact"
        static let delete = "emergency_contact/delete"
        static func verify(id: String) -> String {
            return "emergency_verifications/" + id
        }
    }
    
    public func createContact(identityNumber: String, completion: @escaping (APIResult<EmergencyResponse>) -> Void) {
        let req = EmergencyRequest(phone: nil,
                                   identityNumber: identityNumber,
                                   pin: nil,
                                   code: nil,
                                   purpose: .contact)
        request(method: .post,
                url: Url.create,
                parameters: req.toParameters(),
                encoding: EncodableParameterEncoding<EmergencyRequest>(),
                completion: completion)
    }
    
    public func verifyContact(pin: String, id: String, code: String, completion: @escaping (APIResult<Account>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { (encryptedPin) in
            let req = EmergencyRequest(phone: nil,
                                       identityNumber: nil,
                                       pin: encryptedPin,
                                       code: code,
                                       purpose: .contact)
            request(method: .post,
                    url: Url.verify(id: id),
                    parameters: req.toParameters(),
                    encoding: EncodableParameterEncoding<EmergencyRequest>(),
                    completion: completion)
        }
    }
    
    public func createSession(phoneNumber: String, identityNumber: String, completion: @escaping (APIResult<EmergencyResponse>) -> Void) {
        let req = EmergencyRequest(phone: phoneNumber,
                                   identityNumber: identityNumber,
                                   pin: nil,
                                   code: nil,
                                   purpose: .session)
        request(method: .post,
                url: Url.create,
                parameters: req.toParameters(),
                encoding: EncodableParameterEncoding<EmergencyRequest>(),
                checkLogin: false,
                completion: completion)
    }
    
    public func verifySession(id: String, code: String, sessionSecret: String?, registrationId: Int?, completion: @escaping (APIResult<Account>) -> Void) {
        let req = EmergencySessionRequest(code: code,
                                          sessionSecret: sessionSecret,
                                          registrationId: registrationId)
        request(method: .post,
                url: Url.verify(id: id),
                parameters: req.toParameters(),
                encoding: EncodableParameterEncoding<EmergencySessionRequest>(),
                checkLogin: false,
                completion: completion)
    }
    
    public func show(pin: String, completion: @escaping (APIResult<User>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { (encryptedPin) in
            let param = ["pin": encryptedPin]
            request(method: .post, url: Url.show, parameters: param, completion: completion)
        }
    }
    
    public func delete(pin: String, completion: @escaping (APIResult<Account>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { (encryptedPin) in
            let param = ["pin": encryptedPin]
            request(method: .post, url: Url.delete, parameters: param, completion: completion)
        }
    }
    
}
