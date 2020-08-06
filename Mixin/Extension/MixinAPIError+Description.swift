import Foundation
import MixinServices

extension MixinAPIError {
    
    var localizedDescription: String {
        switch self {
        case .prerequistesNotFulfilled:
            return R.string.localizable.toast_operation_failed()
        case .invalidHTTPStatusCode:
            return Localized.TOAST_API_ERROR_SERVER_5XX
        case .invalidJSON:
            return R.string.localizable.toast_operation_failed()
        case let .httpTransport(error):
            if let underlying = error.underlyingError, (underlying as NSError).domain == NSURLErrorDomain {
                switch (underlying as NSError).code {
                case NSURLErrorNotConnectedToInternet, NSURLErrorCannotConnectToHost:
                    return Localized.TOAST_API_ERROR_NO_CONNECTION
                case NSURLErrorTimedOut:
                    return R.string.localizable.toast_api_error_connection_timeout()
                case NSURLErrorNetworkConnectionLost:
                    return Localized.TOAST_API_ERROR_NETWORK_CONNECTION_LOST
                default:
                    return R.string.localizable.toast_operation_failed()
                }
            } else {
                return R.string.localizable.toast_operation_failed()
            }
        case .webSocketTimeOut:
            return R.string.localizable.toast_api_error_connection_timeout()
        case let .unknown(code, status):
            return R.string.localizable.toast_operation_failed()
            
        case .invalidRequestBody:
            return R.string.localizable.toast_operation_failed()
        case .unauthorized:
            return R.string.localizable.toast_operation_failed()
        case .forbidden:
            return R.string.localizable.toast_api_error_forbidden()
        case .endpointNotFound:
            return Localized.TOAST_API_ERROR_NOT_FOUND
        case .tooManyRequests:
            return Localized.TOAST_API_ERROR_TOO_MANY_REQUESTS
            
        case .internalServerError, .blazeServerError, .blazeOperationTimedOut:
            return Localized.TOAST_API_ERROR_SERVER_5XX
            
        case .invalidRequestData:
            return R.string.localizable.toast_operation_failed()
        case .failedToDeliverSMS:
            return R.string.localizable.toast_operation_failed()
        case .invalidReCaptcha:
            return Localized.TOAST_RECAPTCHA_INVALID
        case .requiresReCaptcha:
            return R.string.localizable.toast_operation_failed()
        case .requiresUpdate:
            return R.string.localizable.toast_operation_failed()
        case .invalidPhoneNumber:
            return R.string.localizable.toast_operation_failed()
        case .insufficientIdentityNumber:
            return R.string.localizable.toast_operation_failed()
        case .invalidInvitationCode:
            return R.string.localizable.toast_operation_failed()
        case .invalidPhoneVerificationCode:
            return R.string.localizable.toast_operation_failed()
        case .expiredPhoneVerificationCode:
            return R.string.localizable.toast_operation_failed()
        case .invalidQrCode:
            return R.string.localizable.toast_operation_failed()
        case .groupChatIsFull:
            return Localized.GROUP_JOIN_FAIL_FULL
        case .insufficientBalance:
            return Localized.TRANSFER_ERROR_BALANCE_INSUFFICIENT
        case .malformedPin, .incorrectPin:
            return Localized.TRANSFER_ERROR_PIN_INCORRECT
        case .transferAmountTooSmall:
            return Localized.TRANSFER_ERROR_AMOUNT_TOO_SMALL
        case .expiredAuthorizationCode:
            return R.string.localizable.toast_operation_failed()
        case .phoneNumberInUse:
            return Localized.TOAST_API_ERROR_UNAVAILABLE_PHONE_NUMBER
        case .tooManyAppsCreated:
            return R.string.localizable.toast_operation_failed()
        case .insufficientFee:
            return Localized.TRANSFER_ERROR_FEE_INSUFFICIENT
        case .transferIsAlreadyPaid:
            return R.string.localizable.toast_operation_failed()
        case .tooManyStickers:
            return Localized.STICKER_ADD_LIMIT
        case .withdrawAmountTooSmall:
            return Localized.WITHDRAWAL_AMOUNT_TOO_SMALL
        case .tooManyFriends:
            return R.string.localizable.toast_operation_failed()
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
            return R.string.localizable.toast_operation_failed()
            
        case .chainNotInSync:
            return Localized.WALLET_BLOCKCHIAN_NOT_IN_SYNC
        case .missingPrivateKey:
            return R.string.localizable.toast_operation_failed()
        case .malformedAddress:
            return Localized.ADDRESS_FORMAT_ERROR
        case .insufficientPool:
            return R.string.localizable.toast_operation_failed()
            
        case .invalidParameters:
            return R.string.localizable.toast_operation_failed()
        case .invalidSDP:
            return R.string.localizable.toast_operation_failed()
        case .invalidCandidate:
            return R.string.localizable.toast_operation_failed()
        case .roomFull:
            return R.string.localizable.toast_operation_failed()
        case .peerNotFound:
            return R.string.localizable.toast_operation_failed()
        case .peerClosed:
            return R.string.localizable.toast_operation_failed()
        case .trackNotFound:
            return R.string.localizable.toast_operation_failed()
        }
    }
    
    func localizedDescription(overridingNotFoundDescriptionWith notFoundDescription: String) -> String {
        switch self {
        case .endpointNotFound:
            return notFoundDescription
        default:
            return localizedDescription
        }
    }
    
}
