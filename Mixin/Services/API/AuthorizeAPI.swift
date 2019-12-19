import Foundation
import Alamofire

final class AuthorizeAPI: BaseAPI {

    static let shared = AuthorizeAPI()

    private enum url {
        static let authorizations = "authorizations"
        static let cancel = "oauth/cancel"
        static let authorize = "oauth/authorize"
    }

    func authorizations(completion: @escaping (APIResult<[AuthorizationResponse]>) -> Void) {
        request(method: .get, url: url.authorizations, completion: completion)
    }
    
    func cancel(clientId: String, completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        let param = ["client_id": clientId]
        request(method: .post, url: url.cancel, parameters: param, completion: completion)
    }
    
    func authorize(authorization: AuthorizationRequest, completion: @escaping (APIResult<AuthorizationResponse>) -> Void) {
        request(method: .post, url: url.authorize, parameters: authorization.toParameters(), encoding: EncodableParameterEncoding<AuthorizationRequest>(), completion: completion)
    }

}
