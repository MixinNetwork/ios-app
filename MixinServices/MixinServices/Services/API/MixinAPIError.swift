import Foundation
import Alamofire

public enum MixinAPIError: Error {
    
    case foundNilResult
    
    case invalidJSON(Error)
    case invalidServerPinToken
    case invalidPath
    case httpTransport(AFError)
    case requestSigningTimeout
    case clockSkewDetected
    case pinEncryption(Error)
    case invalidSignature
    
    case response(MixinAPIResponseError)
    
    public var isTransportTimedOut: Bool {
        switch self {
        case .clockSkewDetected, .requestSigningTimeout:
            return true
        case let .httpTransport(error):
            guard let underlying = (error.underlyingError as NSError?) else {
                return false
            }
            return underlying.domain == NSURLErrorDomain && underlying.code == NSURLErrorTimedOut
        default:
            return false
        }
    }
    
    public var isClientError: Bool {
        switch self {
        case let .httpTransport(.responseValidationFailed(reason: .unacceptableStatusCode(status))):
            return status >= 400 && status < 500
        case let .response(error):
            return error.status >= 400 && error.status < 500
        default:
            return false
        }
    }
    
    public var isServerError: Bool {
        switch self {
        case let .httpTransport(.responseValidationFailed(reason: .unacceptableStatusCode(status))):
            return status >= 500
        case let .response(error):
            return error.status >= 500
        default:
            return false
        }
    }
    
    public var worthRetrying: Bool {
        if isClientError || isServerError {
            return true
        }
        switch self {
        case .httpTransport(let error):
            return error.worthRetrying
        case .clockSkewDetected:
            return true
        default:
            return false
        }
    }
    
}
