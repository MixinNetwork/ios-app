import Foundation
import Alamofire

final class AuthorizeAPI: BaseAPI {

    static let shared = AuthorizeAPI()

    private enum url {
        static let authorize = "oauth/authorize"
    }

    func authorize(authorization: AuthorizationRequest, completion: @escaping (APIResult<AuthorizationResponse>) -> Void) {
        request(method: .post, url: url.authorize, parameters: authorization.toParameters(), encoding: EncodableParameterEncoding<AuthorizationRequest>(), toastError: false, completion: completion)
    }

}
