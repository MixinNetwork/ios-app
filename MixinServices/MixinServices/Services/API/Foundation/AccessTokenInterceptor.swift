import UIKit
import Alamofire

class AccessTokenInterceptor: RequestInterceptor {
    
    func adapt(_ urlRequest: URLRequest, for session: Alamofire.Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var request = urlRequest
        request.allHTTPHeaderFields = RequestSigning.signedHeaders(for: request)
        completion(.success(request))
    }
    
}
