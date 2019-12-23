import Foundation

public struct APIError: Error, Codable {

    let status: Int
    let code: Int
    var description: String

}

extension APIError {

    static func createError(error: Error, status: Int) -> APIError {
        let err = error as NSError
        return APIError(status: status, code: err.errorCode, description: err.localizedDescription)
    }

    static func createAuthenticationError() -> APIError {
        return APIError(status: 401, code: 401, description: "")
    }

    static func createTimeoutError() -> APIError {
        return APIError(status: NSURLErrorTimedOut, code: NSURLErrorTimedOut, description: "")
    }
    
    var isClientError: Bool {
        switch status {
        case NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost:
            return true
        default:
            return (code >= 400 && code < 500) || (status >= 400 && status < 500)
        }
    }

    var isServerError: Bool {
        return (code >= 500 && code < 600) || (status >= 500 && status < 600)
    }

}

extension APIError: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        return "status: \(status), code: \(code), description: \(description)"
    }

}
