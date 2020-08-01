import Alamofire
import MixinServices

final class MultisigAPI: MixinAPI {
    
    static let shared = MultisigAPI()
    
    private enum url {
        static func cancel(id: String) -> String {
            return "multisigs/\(id)/cancel"
        }
        static func sign(id: String) -> String {
            return "multisigs/\(id)/sign"
        }
        static func unlock(id: String) -> String {
            return "multisigs/\(id)/unlock"
        }
    }
    
    func cancel(requestId: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        request(method: .post, url: url.cancel(id: requestId), completion: completion)
    }
    
    func sign(requestId: String, pin: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { [weak self](encryptedPin) in
            self?.request(method: .post, url: url.sign(id: requestId), parameters: ["pin": encryptedPin], completion: completion)
        }
    }
    
    func unlock(requestId: String, pin: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { [weak self](encryptedPin) in
            self?.request(method: .post, url: url.unlock(id: requestId), parameters: ["pin": encryptedPin], completion: completion)
        }
    }
    
}
