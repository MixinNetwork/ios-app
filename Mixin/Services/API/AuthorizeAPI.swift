import Foundation
import Alamofire

public final class AuthorizeAPI: BaseAPI {

    public static let shared = AuthorizeAPI()

    private enum url {
        static let authorizations = "authorizations"
        static let cancel = "oauth/cancel"
        static let authorize = "oauth/authorize"
    }

    public func authorizations(completion: @escaping (APIResult<[AuthorizationResponse]>) -> Void) {
        request(method: .get, url: url.authorizations, completion: completion)
    }
    
    public func cancel(clientId: String, completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        let param = ["client_id": clientId]
        request(method: .post, url: url.cancel, parameters: param, completion: completion)
    }
    
    public func authorize(authorization: AuthorizationRequest, completion: @escaping (APIResult<AuthorizationResponse>) -> Void) {
        request(method: .post, url: url.authorize, parameters: authorization.toParameters(), encoding: EncodableParameterEncoding<AuthorizationRequest>(), completion: completion)
    }

}
