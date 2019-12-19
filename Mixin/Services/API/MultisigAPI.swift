import Foundation

public final class MultisigAPI: BaseAPI {
    
    public static let shared = MultisigAPI()
    
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
    
    public func cancel(requestId: String, completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        request(method: .post, url: url.cancel(id: requestId), completion: completion)
    }
    
    public func sign(requestId: String, pin: String, completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { [weak self](encryptedPin) in
            self?.request(method: .post, url: url.sign(id: requestId), parameters: ["pin": encryptedPin], completion: completion)
        }
    }
    
    public func unlock(requestId: String, pin: String, completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { [weak self](encryptedPin) in
            self?.request(method: .post, url: url.unlock(id: requestId), parameters: ["pin": encryptedPin], completion: completion)
        }
    }
    
}
