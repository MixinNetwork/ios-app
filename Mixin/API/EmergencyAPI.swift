import Foundation

final class EmergencyAPI: BaseAPI {
    
    static let shared = EmergencyAPI()
    
    private enum Url {
        static let create = "emergency_verifications"
        static let show = "emergency_contact"
        static func verify(id: String) -> String {
            return "emergency_verifications/" + id
        }
    }
    
    func createContact(identityNumber: String, pin: String, completion: @escaping (APIResult<EmergencyResponse>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { (encryptedPin) in
            let req = EmergencyRequest(phone: nil,
                                       identityNumber: identityNumber,
                                       pin: encryptedPin,
                                       code: nil,
                                       purpose: .contact)
            self.request(method: .post,
                         url: Url.create,
                         parameters: req.toParameters(),
                         encoding: EncodableParameterEncoding<EmergencyRequest>(),
                         completion: completion)
        }
    }
    
    func createSession(phoneNumber: String, identityNumber: String, completion: @escaping (APIResult<EmergencyResponse>) -> Void) {
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
    
    func verifyContact(id: String, code: String, completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        let req = EmergencyRequest(phone: nil,
                                   identityNumber: nil,
                                   pin: nil,
                                   code: code,
                                   purpose: .contact)
        request(method: .post,
                url: Url.verify(id: id),
                parameters: req.toParameters(),
                encoding: EncodableParameterEncoding<EmergencyRequest>(),
                completion: completion)
    }
    
    func verifySession(id: String, code: String, sessionSecret: String?, registrationId: Int?, completion: @escaping (APIResult<Account>) -> Void) {
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
    
    func show(completion: @escaping (APIResult<User>) -> Void) {
        request(method: .get, url: Url.show, completion: completion)
    }
    
}
