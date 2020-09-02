import Foundation
import MixinServices

extension MixinAPIError {
    
    var localizedDescription: String {
        switch self {
        case .prerequistesNotFulfilled:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .invalidHTTPStatusCode:
            return Localized.TOAST_API_ERROR_SERVER_5XX
        case .invalidJSON:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case let .httpTransport(error):
            if let underlying = error.underlyingError, (underlying as NSError).domain == NSURLErrorDomain {
                switch (underlying as NSError).code {
                case NSURLErrorNotConnectedToInternet, NSURLErrorCannotConnectToHost:
                    return Localized.TOAST_API_ERROR_NO_CONNECTION
                case NSURLErrorTimedOut:
                    return MixinServices.Localized.TOAST_API_ERROR_CONNECTION_TIMEOUT
                case NSURLErrorNetworkConnectionLost:
                    return Localized.TOAST_API_ERROR_NETWORK_CONNECTION_LOST
                default:
                    return MixinServices.Localized.TOAST_OPERATION_FAILED
                }
            } else {
                return MixinServices.Localized.TOAST_OPERATION_FAILED
            }
        case .webSocketTimeOut:
            return MixinServices.Localized.TOAST_API_ERROR_CONNECTION_TIMEOUT
        case let .unknown(code, status):
            return MixinServices.Localized.TOAST_OPERATION_FAILED
            
        case .invalidRequestBody:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .unauthorized:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .forbidden:
            return R.string.localizable.toast_api_error_forbidden()
        case .notFound:
            return Localized.TOAST_API_ERROR_NOT_FOUND
        case .tooManyRequests:
            return Localized.TOAST_API_ERROR_TOO_MANY_REQUESTS
            
        case .internalServerError, .blazeServerError, .blazeOperationTimedOut:
            return Localized.TOAST_API_ERROR_SERVER_5XX
            
        case .invalidRequestData:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .failedToDeliverSMS:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .invalidReCaptcha:
            return Localized.TOAST_RECAPTCHA_INVALID
        case .requiresReCaptcha:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .requiresUpdate:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .invalidPhoneNumber:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .insufficientIdentityNumber:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .invalidInvitationCode:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .invalidPhoneVerificationCode:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .expiredPhoneVerificationCode:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .invalidQrCode:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .groupChatIsFull:
            return Localized.GROUP_JOIN_FAIL_FULL
        case .insufficientBalance:
            return Localized.TRANSFER_ERROR_BALANCE_INSUFFICIENT
        case .malformedPin, .incorrectPin:
            return Localized.TRANSFER_ERROR_PIN_INCORRECT
        case .transferAmountTooSmall:
            return Localized.TRANSFER_ERROR_AMOUNT_TOO_SMALL
        case .expiredAuthorizationCode:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .phoneNumberInUse:
            return Localized.TOAST_API_ERROR_UNAVAILABLE_PHONE_NUMBER
        case .tooManyAppsCreated:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .insufficientFee:
            return Localized.TRANSFER_ERROR_FEE_INSUFFICIENT
        case .transferIsAlreadyPaid:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .tooManyStickers:
            return Localized.STICKER_ADD_LIMIT
        case .withdrawAmountTooSmall:
            return Localized.WITHDRAWAL_AMOUNT_TOO_SMALL
        case .tooManyFriends:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .sendingVerificationCodeTooFrequently:
            return R.string.localizable.text_invalid_code_too_frequent()
        case .invalidEmergencyContact:
            return R.string.localizable.text_invalid_emergency_id()
        case .malformedWithdrawalMemo:
            return R.string.localizable.withdrawal_memo_format_incorrect()
        case .sharedAppReachLimit:
            return R.string.localizable.profile_shared_app_reach_limit()
        case .circleConversationReachLimit:
            return R.string.localizable.circle_conversation_add_reach_limit()
        case .invalidConversationChecksum:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
            
        case .chainNotInSync:
            return Localized.WALLET_BLOCKCHIAN_NOT_IN_SYNC
        case .missingPrivateKey:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .malformedAddress:
            return Localized.ADDRESS_FORMAT_ERROR
        case .insufficientPool:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
            
        case .invalidParameters:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .invalidSDP:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .invalidCandidate:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .roomFull:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .peerNotFound:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .peerClosed:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        case .trackNotFound:
            return MixinServices.Localized.TOAST_OPERATION_FAILED
        }
    }
    
    func localizedDescription(overridingNotFoundDescriptionWith notFoundDescription: String) -> String {
        switch self {
        case .notFound:
            return notFoundDescription
        default:
            return localizedDescription
        }
    }
    
}
