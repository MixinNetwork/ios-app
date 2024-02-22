import Foundation
import MixinServices

extension MixinAPIError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return R.string.localizable.data_parsing_error()
        case let .httpTransport(error):
            if let underlying = (error.underlyingError as NSError?), underlying.domain == NSURLErrorDomain {
                let description = switch underlying.code {
                case NSURLErrorNotConnectedToInternet, NSURLErrorCannotConnectToHost:
                    R.string.localizable.no_network_connection()
                case NSURLErrorTimedOut:
                    R.string.localizable.error_connection_timeout()
                case NSURLErrorNetworkConnectionLost:
                    R.string.localizable.network_connection_lost()
                default:
                    underlying.localizedDescription
                }
                return R.string.localizable.error_two_parts("\(underlying.code)", description)
            } else {
                switch error {
                case let .responseValidationFailed(.unacceptableStatusCode(code)):
                    return R.string.localizable.error_two_parts("\(code)", R.string.localizable.mixin_server_encounters_errors())
                default:
                    return R.string.localizable.error_network_task_failed()
                }
            }
        case .clockSkewDetected, .requestSigningTimeout:
            return R.string.localizable.error_connection_timeout()
        case let .response(error):
            return error.localizedDescription
        default:
            return "\(self)"
        }
    }
    
    public func localizedDescription(overridingNotFoundDescriptionWith notFoundDescription: String) -> String {
        switch self {
        case .response(let error):
            return error.localizedDescription(overridingNotFoundDescriptionWith: notFoundDescription)
        default:
            return localizedDescription
        }
    }
    
}
