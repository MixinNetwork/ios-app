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

public struct MixinAPIResponseError: Error, Codable {
    
    public let status: Int
    public let code: Int
    public let description: String?
    
    private init(status: Int, code: Int, description: String? = nil) {
        self.status = status
        self.code = code
        self.description = description
    }
    
}

extension MixinAPIResponseError {
    
    var isClientErrorResponse: Bool {
        status >= 400 && status < 500
    }
    
    public var isServerErrorResponse: Bool {
        status >= 500
    }
    
}

extension MixinAPIResponseError {
    
    public static let invalidRequestBody                   = MixinAPIResponseError(status: 202, code: 400)
    public static let unauthorized                         = MixinAPIResponseError(status: 202, code: 401)
    public static let forbidden                            = MixinAPIResponseError(status: 202, code: 403)
    public static let notFound                             = MixinAPIResponseError(status: 202, code: 404)
    public static let tooManyRequests                      = MixinAPIResponseError(status: 202, code: 429)
    
    public static let internalServerError                  = MixinAPIResponseError(status: 500, code: 500)
    public static let blazeServerError                     = MixinAPIResponseError(status: 500, code: 7000)
    public static let blazeOperationTimedOut               = MixinAPIResponseError(status: 500, code: 7001)
    
    public static let invalidRequestData                   = MixinAPIResponseError(status: 202, code: 10002)
    public static let failedToDeliverSMS                   = MixinAPIResponseError(status: 202, code: 10003)
    public static let invalidCaptchaToken                  = MixinAPIResponseError(status: 202, code: 10004)
    public static let requiresCaptcha                      = MixinAPIResponseError(status: 202, code: 10005)
    public static let requiresUpdate                       = MixinAPIResponseError(status: 202, code: 10006)
    public static let addressGenerating                    = MixinAPIResponseError(status: 202, code: 10104)
    public static let notRegisteredToSafe                  = MixinAPIResponseError(status: 202, code: 10404)
    public static let invalidPhoneNumber                   = MixinAPIResponseError(status: 202, code: 20110)
    public static let invalidPhoneVerificationCode         = MixinAPIResponseError(status: 202, code: 20113)
    public static let expiredPhoneVerificationCode         = MixinAPIResponseError(status: 202, code: 20114)
    public static let invalidQrCode                        = MixinAPIResponseError(status: 202, code: 20115)
    public static let groupChatIsFull                      = MixinAPIResponseError(status: 202, code: 20116)
    public static let insufficientBalance                  = MixinAPIResponseError(status: 202, code: 20117)
    public static let malformedPin                         = MixinAPIResponseError(status: 202, code: 20118)
    public static let incorrectPin                         = MixinAPIResponseError(status: 202, code: 20119)
    public static let transferAmountTooSmall               = MixinAPIResponseError(status: 202, code: 20120)
    public static let expiredAuthorizationCode             = MixinAPIResponseError(status: 202, code: 20121)
    public static let phoneNumberInUse                     = MixinAPIResponseError(status: 202, code: 20122)
    public static let insufficientFee                      = MixinAPIResponseError(status: 202, code: 20124)
    public static let transferIsAlreadyPaid                = MixinAPIResponseError(status: 202, code: 20125)
    public static let tooManyStickers                      = MixinAPIResponseError(status: 202, code: 20126)
    public static let withdrawAmountTooSmall               = MixinAPIResponseError(status: 202, code: 20127)
    public static let tooManyFriends                       = MixinAPIResponseError(status: 202, code: 20128)
    public static let sendingVerificationCodeTooFrequently = MixinAPIResponseError(status: 202, code: 20129)
    public static let invalidEmergencyContact              = MixinAPIResponseError(status: 202, code: 20130)
    public static let malformedWithdrawalMemo              = MixinAPIResponseError(status: 202, code: 20131)
    public static let sharedAppReachLimit                  = MixinAPIResponseError(status: 202, code: 20132)
    public static let circleConversationReachLimit         = MixinAPIResponseError(status: 202, code: 20133)
    public static let withdrawFeeTooSmall                  = MixinAPIResponseError(status: 202, code: 20135)
    public static let withdrawSuspended                    = MixinAPIResponseError(status: 202, code: 20137)
    public static let invalidConversationChecksum          = MixinAPIResponseError(status: 202, code: 20140)
    
    public static let chainNotInSync                       = MixinAPIResponseError(status: 202, code: 30100)
    public static let malformedAddress                     = MixinAPIResponseError(status: 202, code: 30102)
    public static let insufficientPool                     = MixinAPIResponseError(status: 202, code: 30103)
    
    public static let roomFull                             = MixinAPIResponseError(status: 202, code: 5002000)
    public static let peerNotFound                         = MixinAPIResponseError(status: 202, code: 5002001)
    public static let peerClosed                           = MixinAPIResponseError(status: 202, code: 5002002)
    public static let trackNotFound                        = MixinAPIResponseError(status: 202, code: 5002003)
    public static let invalidTransition                    = MixinAPIResponseError(status: 500, code: 5003002)
    
    public static func ~=(lhs: Self, rhs: Error) -> Bool {
        switch rhs {
        case let .response(rhs) as MixinAPIError:
            lhs.status == rhs.status && lhs.code == rhs.code
        case let rhs as MixinAPIResponseError:
            lhs.status == rhs.status && lhs.code == rhs.code
        default:
            false
        }
    }
    
}
