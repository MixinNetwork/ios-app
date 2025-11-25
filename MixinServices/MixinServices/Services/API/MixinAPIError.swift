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
    case pinEncryptionFailed(Error)
    case invalidSignature
    case emptyResponse
    
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
    
    public var worthRetrying: Bool {
        if isClientErrorResponse || isServerErrorResponse {
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
    
    public var worthReporting: Bool {
        switch self {
        case .httpTransport, .response:
            false
        default:
            true
        }
    }
    
    public var isClientErrorResponse: Bool {
        switch self {
        case let .httpTransport(.responseValidationFailed(reason: .unacceptableStatusCode(status))):
            return status >= 400 && status < 500
        case let .response(error):
            return error.isClientErrorResponse
        default:
            return false
        }
    }
    
    public var isServerErrorResponse: Bool {
        switch self {
        case let .httpTransport(.responseValidationFailed(reason: .unacceptableStatusCode(status))):
            return status >= 500
        case let .response(error):
            return error.isServerErrorResponse
        default:
            return false
        }
    }
    
}
