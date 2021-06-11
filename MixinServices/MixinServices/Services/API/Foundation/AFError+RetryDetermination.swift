import Foundation
import Alamofire

extension AFError {
    
    public var worthRetrying: Bool {
        guard
            let underlying = underlyingError as NSError?,
            underlying.domain == NSURLErrorDomain
        else {
            return false
        }
        let codes = [
            NSURLErrorNotConnectedToInternet,
            NSURLErrorTimedOut,
            NSURLErrorNetworkConnectionLost
        ]
        return codes.contains(underlying.code)
    }
    
}
