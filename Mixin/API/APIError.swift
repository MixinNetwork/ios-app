import Foundation

struct APIError: Error, Encodable {
    
    let code: Int
    let status: Int // HTTP Status Code in most cases
    let kind: Kind
    
    var description = ""
    
    init(code: Int, status: Int, description: String) {
        self.init(code: code, status: status, description: description, kind: Kind(code: code))
    }
    
    init(code: Int, status: Int, description: String, kind: Kind) {
        self.code = code
        self.status = status
        self.description = description
        self.kind = kind
    }

    func toError() -> Error {
        return NSError(domain: "APIErrorDomain", code: code, userInfo: nil)
    }

    func toJobError() -> JobError {
        switch code {
        case 400..<500:
            return JobError.clientError(code: code)
        case 500..<600:
            return JobError.serverError(code: code)
        default:
            return JobError.networkError
        }
    }
}

extension APIError: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case code
        case status
        case description
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(Int.self, forKey: .code)
        status = try container.decode(Int.self, forKey: .status)
        description = try container.decode(String.self, forKey: .description)
        kind = Kind(code: code)
    }
    
}

extension APIError {
    
    static let invalidCode = -999999
    
    static func badResponse(status: Int, description: String) -> APIError {
        return self.init(code: invalidCode, status: status, description: description, kind: .badResponse)
    }
    
    static func jsonDecodingFailed(status: Int, description: String) -> APIError {
        return self.init(code: invalidCode, status: status, description: description, kind: .jsonDecodingFailed)
    }
    
}

extension APIError {
    
    enum Kind {
        case cancelled
        case notConnectedToInternet
        case timedOut
        case networkConnectionLost
        case badResponse
        case jsonDecodingFailed
        case badRequest
        case invalidAPITokenHeader
        case forbidden
        case notFound
        case tooManyRequests
        case internalServerError
        case phoneVerificationInvalid
        case reachedFriendLimit
        case invalidInvitationCode
        case invalidVerificationCode
        case invalidQRCode
        case groupChatFull
        case invalidPinFormat
        case insufficientBalance
        case insufficientFee
        case pinIncorrect
        case transferTooSmall
        case unavailablePhoneNumber
        case blockchainNotInSync
        case invalidAddressFormat
        case unhandled

        init(code: Int) {
            switch code {
            case NSURLErrorCancelled:
                self = .cancelled
            case NSURLErrorNotConnectedToInternet:
                self = .notConnectedToInternet
            case NSURLErrorTimedOut:
                self = .timedOut
            case NSURLErrorNetworkConnectionLost:
                self = .networkConnectionLost
            case 400:
                self = .badRequest
            case 401:
                self = .invalidAPITokenHeader
            case 403:
                self = .forbidden
            case 404:
                self = .notFound
            case 429:
                self = .tooManyRequests
            case 500:
                self = .internalServerError
            case 12013:
                self = .phoneVerificationInvalid
            case 12031:
                self = .reachedFriendLimit
            case 20112:
                self = .invalidInvitationCode
            case 20113:
                self = .invalidVerificationCode
            case 20115:
                self = .invalidQRCode
            case 20116:
                self = .groupChatFull
            case 20117:
                self = .insufficientBalance
            case 20118:
                self = .invalidPinFormat
            case 20119:
                self = .pinIncorrect
            case 20120:
                self = .transferTooSmall
            case 20122:
                self = .unavailablePhoneNumber
            case 20124:
                self = .insufficientFee
            case 30100:
                self = .blockchainNotInSync
            case 30102:
                self = .invalidAddressFormat
            default:
                self = .unhandled
            }
        }

        var localizedDescription: String? {
            switch self {
            case .notConnectedToInternet:
                return Localized.TOAST_API_ERROR_NO_CONNECTION
            case .timedOut:
                return Localized.TOAST_API_ERROR_CONNECTION_TIMEOUT
            case .networkConnectionLost:
                return Localized.TOAST_API_ERROR_NETWORK_CONNECTION_LOST
            case .internalServerError:
                return Localized.TOAST_SERVER_ERROR
            case .forbidden:
                return Localized.TOAST_API_ERROR_FORBIDDEN
            case .tooManyRequests:
                return Localized.TOAST_API_ERROR_TOO_MANY_REQUESTS
            case .insufficientBalance:
                return Localized.TRANSFER_ERROR_BALANCE_INSUFFICIENT
            case .insufficientFee:
                return Localized.TRANSFER_ERROR_FEE_INSUFFICIENT
            case .pinIncorrect, .invalidPinFormat:
                return Localized.TRANSFER_ERROR_PIN_INCORRECT
            case .transferTooSmall:
                return Localized.TRANSFER_ERROR_AMOUNT_TOO_SMALL
            case .groupChatFull:
                return Localized.GROUP_JOIN_FAIL_FULL
            case .unavailablePhoneNumber:
                return Localized.TOAST_API_ERROR_UNAVAILABLE_PHONE_NUMBER
            case .blockchainNotInSync:
                return Localized.WALLET_BLOCKCHIAN_NOT_IN_SYNC
            case .invalidAddressFormat:
                return Localized.ADDRESS_FORMAT_ERROR
            default:
                return nil
            }
        }
    }
    
}
