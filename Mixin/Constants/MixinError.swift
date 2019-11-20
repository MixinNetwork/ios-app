import Foundation

enum MixinError: Error {
    
    case logout(isAsyncRequest: Bool)
    case loadAvatar(url: URL, error: Error?)
    case invalidPin
    case missingBackup
    case requestLoginVerificationCode([String: Any])
    case generateRsaKeyPair
    case unrecognizedReCaptchaMessage(String)
    
}

extension MixinError: CustomNSError {
    
    public static var errorDomain: String {
        return "MixinError"
    }
    
    public var errorCode: Int {
        switch self {
        case .logout:
            return 0
        case .loadAvatar:
            return 1
        case .invalidPin:
            return 2
        case .missingBackup:
            return 3
        case .requestLoginVerificationCode:
            return 4
        case .generateRsaKeyPair:
            return 5
        case .unrecognizedReCaptchaMessage:
            return 6
        }
    }
    
    public var errorUserInfo: [String : Any] {
        switch self {
        case let .logout(isAsyncRequest):
            return ["isAsyncRequest": isAsyncRequest]
        case let .loadAvatar(url, error):
            return ["url": url, "error": error ?? "(null)"]
        case .invalidPin, .missingBackup, .generateRsaKeyPair:
            return [:]
        case let .requestLoginVerificationCode(info):
            return info
        case let .unrecognizedReCaptchaMessage(body):
            return ["body": body]
        }
    }
    
}
