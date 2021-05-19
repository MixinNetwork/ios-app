import Foundation
import Alamofire

public enum MixinAPIError: Error {
    
    // The nil result error below should not appear in normal cases
    // Debug to reduce it once happended
    case foundNilResult
    
    case prerequistesNotFulfilled
    case invalidJSON(Error)
    case invalidServerPinToken
    case invalidPath
    case httpTransport(AFError)
    case webSocketTimeOut
    case clockSkewDetected
    case pinEncryption(Error)
    case unknown(status: Int, code: Int, description: String)
    
    case invalidRequestBody
    case unauthorized
    case forbidden
    case notFound
    case tooManyRequests
    
    case internalServerError
    case blazeServerError
    case blazeOperationTimedOut
    
    case invalidRequestData
    case failedToDeliverSMS
    case invalidCaptchaToken
    case requiresCaptcha
    case requiresUpdate
    case invalidPhoneNumber
    case invalidPhoneVerificationCode
    case expiredPhoneVerificationCode
    case invalidQrCode
    case groupChatIsFull
    case insufficientBalance
    case malformedPin
    case incorrectPin
    case transferAmountTooSmall
    case expiredAuthorizationCode
    case phoneNumberInUse
    case insufficientFee
    case transferIsAlreadyPaid
    case tooManyStickers
    case withdrawAmountTooSmall
    case tooManyFriends
    case sendingVerificationCodeTooFrequently
    case invalidEmergencyContact
    case malformedWithdrawalMemo
    case sharedAppReachLimit
    case circleConversationReachLimit
    case invalidConversationChecksum
    
    case chainNotInSync
    case malformedAddress
    case insufficientPool
    
    case invalidParameters
    case invalidSDP
    case invalidCandidate
    case roomFull
    case peerNotFound
    case peerClosed
    case trackNotFound
    
}

extension MixinAPIError {
    
    init(status: Int, code: Int, description: String) {
        switch (status, code) {
        case (202, 400):
            self = .invalidRequestBody
        case (202, 401):
            self = .unauthorized
        case (202, 403):
            self = .forbidden
        case (202, 404):
            self = .notFound
        case (202, 429):
            self = .tooManyRequests
            
        case (500, 500):
            self = .internalServerError
        case (500, 7000):
            self = .blazeServerError
        case (500, 7001):
            self = .blazeOperationTimedOut
            
        case (202, 10002):
            self = .invalidRequestData
        case (202, 10003):
            self = .failedToDeliverSMS
        case (202, 10004):
            self = .invalidCaptchaToken
        case (202, 10005):
            self = .requiresCaptcha
        case (202, 10006):
            self = .requiresUpdate
        case (202, 20110):
            self = .invalidPhoneNumber
        case (202, 20113):
            self = .invalidPhoneVerificationCode
        case (202, 20114):
            self = .expiredPhoneVerificationCode
        case (202, 20115):
            self = .invalidQrCode
        case (202, 20116):
            self = .groupChatIsFull
        case (202, 20117):
            self = .insufficientBalance
        case (202, 20118):
            self = .malformedPin
        case (202, 20119):
            self = .incorrectPin
        case (202, 20120):
            self = .transferAmountTooSmall
        case (202, 20121):
            self = .expiredAuthorizationCode
        case (202, 20122):
            self = .phoneNumberInUse
        case (202, 20124):
            self = .insufficientFee
        case (202, 20125):
            self = .transferIsAlreadyPaid
        case (202, 20126):
            self = .tooManyStickers
        case (202, 20127):
            self = .withdrawAmountTooSmall
        case (202, 20128):
            self = .tooManyFriends
        case (202, 20129):
            self = .sendingVerificationCodeTooFrequently
        case (202, 20130):
            self = .invalidEmergencyContact
        case (202, 20131):
            self = .malformedWithdrawalMemo
        case (202, 20132):
            self = .sharedAppReachLimit
        case (202, 20133):
            self = .circleConversationReachLimit
        case (202, 20140):
            self = .invalidConversationChecksum
            
        case (202, 30100):
            self = .chainNotInSync
        case (202, 30102):
            self = .malformedAddress
        case (202, 30103):
            self = .insufficientPool
            
        case (202, 5002000):
            self = .roomFull
        case (202, 5002001):
            self = .peerNotFound
        case (202, 5002002):
            self = .peerClosed
        case (202, 5002003):
            self = .trackNotFound
            
        default:
            self = .unknown(status: status, code: code, description: description)
        }
    }
    
}

extension MixinAPIError: Decodable {
    
    enum CodingKeys: CodingKey {
        case code
        case status
        case description
    }
    
    public func encode(to encoder: Encoder) throws {
        fatalError("This func encodes nothing currently")
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(Int.self, forKey: .status)
        let code = try container.decode(Int.self, forKey: .code)
        let description = try container.decode(String.self, forKey: .description)
        self.init(status: status, code: code, description: description)
    }
    
}

extension MixinAPIError {
    
    public var isTransportTimedOut: Bool {
        switch self {
        case .webSocketTimeOut, .clockSkewDetected:
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
        case .invalidRequestBody, .unauthorized, .forbidden, .notFound, .tooManyRequests:
            return true
        case let .httpTransport(.responseValidationFailed(reason: .unacceptableStatusCode(code))):
            return code >= 400 && code < 500
        case let .unknown(status, _, _):
            return status >= 400 && status < 500
        default:
            return false
        }
    }
    
    public var isServerError: Bool {
        switch self {
        case .internalServerError, .blazeServerError, .blazeOperationTimedOut:
            return true
        case .httpTransport(.responseValidationFailed(reason: .unacceptableStatusCode(let code))):
            return code >= 500
        case let .unknown(status, _, _):
            return status >= 500
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
        case .webSocketTimeOut, .clockSkewDetected:
            return true
        default:
            return false
        }
    }
    
}
