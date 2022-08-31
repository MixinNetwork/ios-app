import Alamofire
import MixinServices

public final class MultisigAPI: MixinAPI {
    
    private enum Path {
        static func cancel(id: String) -> String {
            return "/multisigs/\(id)/cancel"
        }
        static func sign(id: String) -> String {
            return "/multisigs/\(id)/sign"
        }
        static func unlock(id: String) -> String {
            return "/multisigs/\(id)/unlock"
        }
    }
    
    public static func cancel(requestId: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        request(method: .post, path: Path.cancel(id: requestId), completion: completion)
    }
    
    public static func sign(requestId: String, pin: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        PINEncryptor.encrypt(pin: pin, tipBody: {
            try TIPBody.signMultisigRequest(id: requestId)
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
            try TIPBody.unlockMultisigRequest(id: requestId)
        }, onFailure: completion) { (encryptedPin) in
            self.request(method: .post,
                         path: Path.unlock(id: requestId),
                         parameters: ["pin_base64": encryptedPin],
                         options: .disableRetryOnRequestSigningTimeout,
                         completion: completion)
        }
    }
    
}
