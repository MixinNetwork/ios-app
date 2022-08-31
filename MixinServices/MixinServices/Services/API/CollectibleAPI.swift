import Alamofire
import MixinServices

public final class CollectibleAPI: MixinAPI {
    
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
    
    public static func cancel(requestId: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        request(method: .post, path: Path.cancel(id: requestId), completion: completion)
    }
    
    public static func sign(requestId: String, pin: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        PINEncryptor.encrypt(pin: pin, tipBody: {
            try TIPBody.signCollectibleRequest(id: requestId)
        }, onFailure: completion) { (encryptedPin) in
            self.request(method: .post,
                         path: Path.sign(id: requestId),
                         parameters: ["pin_base64": encryptedPin],
                         options: .disableRetryOnRequestSigningTimeout,
                         completion: completion)
        }
    }
    
    public static func unlock(requestId: String, pin: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        PINEncryptor.encrypt(pin: pin, tipBody: {
            try TIPBody.unlockCollectibleRequest(id: requestId)
        }, onFailure: completion) { (encryptedPin) in
            self.request(method: .post,
                         path: Path.unlock(id: requestId),
                         parameters: ["pin_base64": encryptedPin],
                         options: .disableRetryOnRequestSigningTimeout,
                         completion: completion)
        }
    }
    
    public static func token(tokenId: String) -> MixinAPI.Result<CollectibleToken> {
        return request(method: .get, path: Path.tokens(id: tokenId))
    }
    
}
