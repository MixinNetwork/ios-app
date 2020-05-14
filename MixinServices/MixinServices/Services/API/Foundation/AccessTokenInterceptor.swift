import UIKit
import Alamofire

class AccessTokenInterceptor: RequestInterceptor {
    
    func adapt(_ urlRequest: URLRequest, for session: Alamofire.Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var urlRequest = urlRequest
        if let signedToken = MixinRequest.getAuthenticationToken(request: urlRequest) {
            urlRequest.setValue(signedToken, forHTTPHeaderField: MixinRequest.headersAuthroizationKey)
        }
        completion(.success(urlRequest))
    }
    
}
