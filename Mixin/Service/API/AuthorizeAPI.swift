import Alamofire
import MixinServices

final class AuthorizeAPI: MixinAPI {
    
    private enum url {
        static let authorizations = "authorizations"
        static let cancel = "oauth/cancel"
        static let authorize = "oauth/authorize"
    }

    static func authorizations(completion: @escaping (MixinAPI.Result<[AuthorizationResponse]>) -> Void) {
        request(method: .get, url: url.authorizations, completion: completion)
    }
    
    static func cancel(clientId: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        let param = ["client_id": clientId]
        request(method: .post, url: url.cancel, parameters: param, completion: completion)
    }
    
    static func authorize(authorization: AuthorizationRequest, completion: @escaping (MixinAPI.Result<AuthorizationResponse>) -> Void) {
        request(method: .post, url: url.authorize, parameters: authorization.toParameters(), encoding: EncodableParameterEncoding<AuthorizationRequest>(), completion: completion)
    }

}
