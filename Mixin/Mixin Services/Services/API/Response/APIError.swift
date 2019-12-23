import Foundation

public struct APIError: Error, Codable {

    public let status: Int
    public let code: Int
    public var description: String

}

extension APIError {

    public static func createError(error: Error, status: Int) -> APIError {
        let err = error as NSError
        return APIError(status: status, code: err.errorCode, description: err.localizedDescription)
    }

    public static func createAuthenticationError() -> APIError {
        return APIError(status: 401, code: 401, description: "")
    }

    public static func createTimeoutError() -> APIError {
        return APIError(status: NSURLErrorTimedOut, code: NSURLErrorTimedOut, description: "")
    }
    
    public var isClientError: Bool {
        switch status {
        case NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost:
            return true
        default:
            return (code >= 400 && code < 500) || (status >= 400 && status < 500)
        }
    }

    public var isServerError: Bool {
        return (code >= 500 && code < 600) || (status >= 500 && status < 600)
    }

}

extension APIError: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        return "status: \(status), code: \(code), description: \(description)"
    }

}
