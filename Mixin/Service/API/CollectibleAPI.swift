import Alamofire
import MixinServices

final class CollectibleAPI: MixinAPI {
    
    private enum Path {
        static func cancel(id: String) -> String {
            return "/collectibles/requests/\(id)/cancel"
        }
        static func sign(id: String) -> String {
            return "/collectibles/requests/\(id)/sign"
        }
        static func unlock(id: String) -> String {
            return "/collectibles/requests/\(id)/unlock"
        }
        static func tokens(id: String) -> String {
            return "/collectibles/tokens/\(id)"
        }
    }
    
    static func cancel(requestId: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        request(method: .post, path: Path.cancel(id: requestId), completion: completion)
    }
    
    static func sign(requestId: String, pin: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        PINEncryptor.encrypt(pin: pin, onFailure: completion) { (encryptedPin) in
            self.request(method: .post,
                         path: Path.sign(id: requestId),
                         parameters: ["pin": encryptedPin],
                         completion: completion)
        }
    }
    
    static func unlock(requestId: String, pin: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        PINEncryptor.encrypt(pin: pin, onFailure: completion) { (encryptedPin) in
            self.request(method: .post,
                         path: Path.unlock(id: requestId),
                         parameters: ["pin": encryptedPin],
                         completion: completion)
        }
    }
    
    static func token(tokenId: String) -> MixinAPI.Result<CollectibleToken> {
        return request(method: .get, path: Path.tokens(id: tokenId))
    }
    
}
