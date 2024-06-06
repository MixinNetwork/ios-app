import Foundation
import MixinServices

extension MixinAPIResponseError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .invalidRequestBody:
            return R.string.localizable.invalid_request_body()
        case .unauthorized:
            return R.string.localizable.unauthorized()
        case .forbidden:
            return R.string.localizable.access_denied()
        case .notFound:
            return R.string.localizable.error_not_found()
        case Self.tooManyRequests:
            return R.string.localizable.error_too_many_request()
            
        case .internalServerError, .blazeServerError, .blazeOperationTimedOut, .insufficientPool:
            return R.string.localizable.mixin_server_encounters_errors()
            
        case .invalidRequestData:
            return R.string.localizable.error_bad_data()
        case .failedToDeliverSMS:
            return R.string.localizable.error_phone_sms_delivery()
        case .invalidCaptchaToken:
            return R.string.localizable.error_captcha_is_invalid()
        case .requiresCaptcha:
            return R.string.localizable.error_requires_captcha()
        case .requiresUpdate:
            return R.string.localizable.app_update_short_hint()
        case .notRegisteredToSafe:
            return R.string.localizable.error_opponent_not_registered_to_safe()
        case .invalidPhoneNumber:
            return R.string.localizable.error_phone_invalid_format()
        case .invalidPhoneVerificationCode:
            return R.string.localizable.error_phone_verification_code_invalid()
        case .expiredPhoneVerificationCode:
            return R.string.localizable.error_phone_verification_code_expired()
        case .invalidQrCode:
            return R.string.localizable.error_two_parts("\(code)", R.string.localizable.invalid_qr_code())
        case .groupChatIsFull:
            return R.string.localizable.error_full_group()
        case .insufficientBalance:
            return R.string.localizable.error_insufficient_balance()
        case .malformedPin:
            return R.string.localizable.error_two_parts("\(code)", R.string.localizable.pin_incorrect())
        case .incorrectPin:
            return R.string.localizable.error_pin_incorrect()
        case .transferAmountTooSmall:
            return R.string.localizable.error_too_small_transfer_amount()
        case .expiredAuthorizationCode:
            return R.string.localizable.error_expired_authorization_code()
        case .phoneNumberInUse:
            return R.string.localizable.error_used_phone()
        case .insufficientFee:
            return R.string.localizable.error_two_parts("\(code)", R.string.localizable.insufficient_transaction_fee())
        case .transferIsAlreadyPaid:
            return R.string.localizable.error_transfer_is_already_paid()
        case .tooManyStickers:
            return R.string.localizable.error_too_many_stickers()
        case .withdrawAmountTooSmall:
            return R.string.localizable.error_too_small_withdraw_amount()
        case .tooManyFriends:
            return R.string.localizable.error_too_many_friends()
        case .sendingVerificationCodeTooFrequently:
            return R.string.localizable.error_invalid_code_too_frequent()
        case .invalidEmergencyContact:
            return R.string.localizable.error_invalid_emergency_contact()
        case .malformedWithdrawalMemo:
            return R.string.localizable.error_withdrawal_memo_format_incorrect()
        case .sharedAppReachLimit:
            return R.string.localizable.error_number_reached_limit()
        case .circleConversationReachLimit:
            return R.string.localizable.conversation_has_too_many_circles()

        case .chainNotInSync:
            return R.string.localizable.error_blockchain()
        case .malformedAddress:
            return R.string.localizable.error_invalid_address_plain()
            
        case .roomFull:
            return R.string.localizable.error_two_parts("\(code)", R.string.localizable.room_is_full())
        case .peerNotFound:
            return R.string.localizable.error_two_parts("\(code)", R.string.localizable.peer_not_found())
        case .peerClosed:
            return R.string.localizable.error_two_parts("\(code)", R.string.localizable.peer_closed())
        case .trackNotFound:
            return R.string.localizable.error_two_parts("\(code)", R.string.localizable.track_not_found())

        default:
            return R.string.localizable.error_two_parts("\(code)", description ?? "")
        }
    }
    
    public func localizedDescription(overridingNotFoundDescriptionWith notFoundDescription: String) -> String {
        switch self {
        case .notFound:
            return notFoundDescription
        default:
            return localizedDescription
        }
    }
    
}
