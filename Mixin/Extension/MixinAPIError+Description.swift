import Foundation
import MixinServices

extension MixinAPIError {
    
    var localizedDescription: String {
        switch self {
        case .invalidJSON:
            return R.string.localizable.data_parsing_error()
        case let .httpTransport(error):
            if let underlying = (error.underlyingError as NSError?), underlying.domain == NSURLErrorDomain {
                switch underlying.code {
                case NSURLErrorNotConnectedToInternet, NSURLErrorCannotConnectToHost:
                    return R.string.localizable.no_network_connection()
                case NSURLErrorTimedOut:
                    return R.string.localizable.error_connection_timeout()
                case NSURLErrorNetworkConnectionLost:
                    return R.string.localizable.network_connection_lost()
                default:
                    return underlying.localizedDescription
                }
            } else {
                switch error {
                case .responseValidationFailed(.unacceptableStatusCode):
                    return R.string.localizable.mixin_server_encounters_errors()
                default:
                    return R.string.localizable.error_network_task_failed()
                }
            }
        case .webSocketTimeout, .clockSkewDetected, .requestSigningTimeout:
            return R.string.localizable.error_connection_timeout()
        case let .unknown(_, code, description):
            return R.string.localizable.error_two_parts("\(code)", description)
            
        case .invalidRequestBody:
            return R.string.localizable.invalid_request_body()
        case .unauthorized:
            return R.string.localizable.unauthorized()
        case .forbidden:
            return R.string.localizable.access_denied()
        case .notFound:
            return R.string.localizable.not_found()
        case .tooManyRequests(let code):
            return R.string.localizable.error_too_many_request(code)
            
        case .internalServerError, .blazeServerError, .blazeOperationTimedOut, .insufficientPool:
            return R.string.localizable.mixin_server_encounters_errors()
            
        case .invalidRequestData:
            return R.string.localizable.invalid_request_data()
        case .failedToDeliverSMS(let code):
            return R.string.localizable.error_phone_sms_delivery(code)
        case .invalidCaptchaToken(let code):
            return R.string.localizable.error_recaptcha_is_invalid(code)
        case .requiresCaptcha:
            return R.string.localizable.error_requires_captcha()
        case .requiresUpdate:
            return R.string.localizable.app_update_short_hint()
        case .invalidPhoneNumber(let code):
            return R.string.localizable.error_phone_invalid_format(code)
        case .invalidPhoneVerificationCode(let code):
            return R.string.localizable.error_phone_verification_code_invalid(code)
        case .expiredPhoneVerificationCode(let code):
            return R.string.localizable.error_phone_verification_code_expired(code)
        case .invalidQrCode:
            return R.string.localizable.invalid_qr_code()
        case .groupChatIsFull(let code):
            return R.string.localizable.error_full_group(code)
        case .insufficientBalance(let code):
            return R.string.localizable.error_insufficient_balance(code)
        case .malformedPin, .incorrectPin:
            return R.string.localizable.pin_incorrect()
        case .transferAmountTooSmall(let code):
            return R.string.localizable.error_too_small_transfer_amount(code)
        case .expiredAuthorizationCode(let code):
            return R.string.localizable.error_phone_verification_code_expired(code)
        case .phoneNumberInUse(let code):
            return R.string.localizable.error_used_phone(code)
        case .insufficientFee:
            return R.string.localizable.insufficient_transaction_fee()
        case .transferIsAlreadyPaid(let code):
            return R.string.localizable.error_transfer_is_already_paid(code)
        case .tooManyStickers(let code):
            return R.string.localizable.error_too_many_stickers(code)
        case .withdrawAmountTooSmall(let code):
            return R.string.localizable.error_too_small_withdraw_amount(code)
        case .tooManyFriends(let code):
            return R.string.localizable.error_too_many_friends(code)
        case .sendingVerificationCodeTooFrequently:
            return R.string.localizable.send_verification_code_frequent()
        case .invalidEmergencyContact(let code):
            return R.string.localizable.error_invalid_emergency_contact(code)
        case .malformedWithdrawalMemo(let code):
            return R.string.localizable.error_withdrawal_memo_format_incorrect(code)
        case .sharedAppReachLimit:
            return R.string.localizable.circle_limit()
        case .circleConversationReachLimit:
            return R.string.localizable.conversation_has_too_many_circles()

        case .chainNotInSync(let code):
            return R.string.localizable.error_blockchain(code)
        case .malformedAddress(let code):
            return R.string.localizable.error_invalid_address_plain(code)
            
        case .invalidParameters:
            return R.string.localizable.invalid_parameters()
        case .invalidSDP:
            return R.string.localizable.invalid_sdp()
        case .invalidCandidate:
            return R.string.localizable.invalid_candidate()
        case .roomFull:
            return R.string.localizable.room_is_full()
        case .peerNotFound:
            return R.string.localizable.peer_not_found()
        case .peerClosed:
            return R.string.localizable.peer_closed()
        case .trackNotFound:
            return R.string.localizable.track_not_found()

        default:
            return R.string.localizable.error_internal_with_msg("\(self)")
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
