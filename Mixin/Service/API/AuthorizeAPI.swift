import Alamofire
import MixinServices

final class AuthorizeAPI: MixinAPI {
    
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
    
    static func authorizations(appId: String? = nil, completion: @escaping (MixinAPI.Result<[AuthorizationResponse]>) -> Void) {
        request(method: .get, path: Path.authorizations(appId: appId), completion: completion)
    }
    
    static func cancel(clientId: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        let param = ["client_id": clientId]
        request(method: .post, path: Path.cancel, parameters: param, completion: completion)
    }
    
    static func authorize(authorization: AuthorizationRequest, completion: @escaping (MixinAPI.Result<AuthorizationResponse>) -> Void) {
        request(method: .post, path: Path.authorize, parameters: authorization, completion: completion)
    }
    
}
