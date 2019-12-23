import Foundation
import MixinServices

extension APIError {
    
    var localizedDescription: String {
        guard let description = serverErrorDescription else {
            return Localized.TOAST_ERROR(errorCode: status, errorMessage: httpErrorDescription)
        }
        
        return Localized.TOAST_ERROR(errorCode: code, errorMessage: description)
    }
    
    private var serverErrorDescription: String? {
        switch code {
        case 403:
            return Localized.TOAST_API_ERROR_FORBIDDEN
        case 404:
            return Localized.TOAST_API_ERROR_NOT_FOUND
        case 429:
            return Localized.TOAST_API_ERROR_TOO_MANY_REQUESTS
        case 500:
            return Localized.TOAST_API_ERROR_SERVER_5XX
        case 10004:
            return Localized.TOAST_RECAPTCHA_INVALID
        case 10006:
            return Localized.TOAST_UPDATE_TIPS
        case 20117:
            return Localized.TRANSFER_ERROR_BALANCE_INSUFFICIENT
        case 20118:
            return Localized.TRANSFER_ERROR_PIN_INCORRECT
        case 20119:
            return Localized.TRANSFER_ERROR_PIN_INCORRECT
        case 20120:
            return Localized.TRANSFER_ERROR_AMOUNT_TOO_SMALL
        case 20129:
            return R.string.localizable.text_invalid_code_too_frequent()
        case 20116:
            return Localized.GROUP_JOIN_FAIL_FULL
        case 20122:
            return Localized.TOAST_API_ERROR_UNAVAILABLE_PHONE_NUMBER
        case 20124:
            return Localized.TRANSFER_ERROR_FEE_INSUFFICIENT
        case 20126:
            return Localized.STICKER_ADD_LIMIT
        case 20127:
            return Localized.WITHDRAWAL_AMOUNT_TOO_SMALL
        case 20131:
            return R.string.localizable.withdrawal_memo_format_incorrect()
        case 20132:
            return R.string.localizable.profile_shared_app_reach_limit()
        case 30100:
            return Localized.WALLET_BLOCKCHIAN_NOT_IN_SYNC
        case 30102:
            return Localized.ADDRESS_FORMAT_ERROR
        default:
            return nil
        }
    }
    
    private var httpErrorDescription: String {
        switch status {
        case NSURLErrorNotConnectedToInternet, NSURLErrorCannotConnectToHost:
            return Localized.TOAST_API_ERROR_NO_CONNECTION
        case NSURLErrorTimedOut:
            return Localized.TOAST_API_ERROR_CONNECTION_TIMEOUT
        case NSURLErrorNetworkConnectionLost:
            return Localized.TOAST_API_ERROR_NETWORK_CONNECTION_LOST
        case 403:
            return Localized.TOAST_API_ERROR_FORBIDDEN
        case 429:
            return Localized.TOAST_API_ERROR_TOO_MANY_REQUESTS
        case 500:
            return Localized.TOAST_API_ERROR_SERVER_5XX
        default:
            return description
        }
    }
    
}
