import Alamofire
import MixinServices

public final class AuthorizeAPI: MixinAPI {
    
    private enum Path {
        static func authorizations(appId: String? = nil) -> String {
            if let appId = appId {
                return "/authorizations?app=\(appId)"
            }
            return "/authorizations"
        }
        static let cancel = "/oauth/cancel"
        static let authorize = "/oauth/authorize"
    }
    
    public static func authorizations(appId: String? = nil, completion: @escaping (MixinAPI.Result<[AuthorizationResponse]>) -> Void) {
        request(method: .get, path: Path.authorizations(appId: appId), completion: completion)
    }
    
    public static func cancel(clientId: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        let param = ["client_id": clientId]
        request(method: .post, path: Path.cancel, parameters: param, completion: completion)
    }
    
    public static func authorize(authorizationId: String, scopes: [String], pin: String?, completion: @escaping (MixinAPI.Result<AuthorizationResponse>) -> Void) {
        func authorize(with parameters: AuthorizationRequest) {
            request(method: .post, path: Path.authorize, parameters: parameters, completion: completion)
        }
        if let pin {
            PINEncryptor.encrypt(pin: pin, tipBody: {
                try TIPBody.authorizeRequest(authorizationId: authorizationId)
            }, onFailure: completion) { (encryptedPin) in
                authorize(with: AuthorizationRequest(authorizationId: authorizationId, scopes: scopes, pin: encryptedPin))
            }
        } else {
            authorize(with: AuthorizationRequest(authorizationId: authorizationId, scopes: scopes, pin: nil))
        }
    }
    
}
