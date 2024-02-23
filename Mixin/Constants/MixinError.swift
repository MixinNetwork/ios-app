import Foundation

enum MixinError: Error {
    
    case loadAvatar(url: URL, error: Error?)
    case invalidPin
    case missingBackup
    case requestLoginVerificationCode([String: String])
    case unrecognizedCaptchaMessage(String)
    case unrecognizedUrl(URL)
    case missingApp
    
}

extension MixinError: CustomNSError {
    
    static var errorDomain: String {
        return "MixinError"
    }
    
    public var errorCode: Int {
        switch self {
        case .loadAvatar:
            return 1
        case .invalidPin:
            return 2
        case .missingBackup:
            return 3
        case .requestLoginVerificationCode:
            return 4
        case .unrecognizedCaptchaMessage:
            return 5
        case .unrecognizedUrl:
            return 6
        case .missingApp:
            return 7
        }
    }
    
    public var errorUserInfo: [String : Any] {
        switch self {
        case let .loadAvatar(url, error):
            return ["url": url, "error": error ?? "(null)"]
        case .invalidPin, .missingBackup, .missingApp:
            return [:]
        case let .requestLoginVerificationCode(info):
            return info
        case let .unrecognizedCaptchaMessage(body):
            return ["body": body]
        case let .unrecognizedUrl(url):
            return ["url": url.absoluteString]
        }
    }
    
}
