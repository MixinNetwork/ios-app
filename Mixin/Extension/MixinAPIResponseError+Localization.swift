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
            return R.string.localizable.error_access_limited()
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
            return R.string.localizable.app_update_short_hint(Bundle.main.shortVersionString)
        case .notRegisteredToSafe:
            return R.string.localizable.error_opponent_not_registered_to_safe()
        case .noAvailableQuote:
            return R.string.localizable.error_no_quote()
        case .invalidQuoteAmount:
            return R.string.localizable.error_invalid_quote_amount()
        case .tokenPairNotSupported:
            return R.string.localizable.error_trading_pair_not_supported()
        case .tooManyAlerts:
            return R.string.localizable.alert_limit_exceeded(100)
        case .tooManyAlertsForAsset:
            return R.string.localizable.alert_per_asset_limit_exceeded(10)
        case .tooManyWallets:
            return R.string.localizable.error_too_many_wallets()
        case .unsupportedWatchAddress:
            return R.string.localizable.error_watch_address_not_supported()
        case .referralCodeNotFound:
            return R.string.localizable.error_invalid_referral_code()
        case .alreadyBondedReferralCode:
            return R.string.localizable.error_already_bonded_referral_code()
        case .referringSelf:
            return R.string.localizable.error_cannot_apply_your_own_referral_code()
        case .inviterPlanExpired:
            return R.string.localizable.error_inviter_plan_expired()
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
