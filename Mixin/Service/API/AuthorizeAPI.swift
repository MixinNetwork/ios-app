import Alamofire
import MixinServices

final class AuthorizeAPI: MixinAPI {
    
    private enum Path {
        static let authorizations = "/authorizations"
        static let cancel = "/oauth/cancel"
        static let authorize = "/oauth/authorize"
    }
    
    static func authorizations(completion: @escaping (MixinAPI.Result<[AuthorizationResponse]>) -> Void) {
        request(method: .get, path: Path.authorizations, completion: completion)
    }
    
    static func cancel(clientId: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        let param = ["client_id": clientId]
        request(method: .post, path: Path.cancel, parameters: param, completion: completion)
    }
    
    static func authorize(authorization: AuthorizationRequest, completion: @escaping (MixinAPI.Result<AuthorizationResponse>) -> Void) {
        request(method: .post, path: Path.authorize, parameters: authorization, completion: completion)
    }
    
}
