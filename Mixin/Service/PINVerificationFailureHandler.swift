import Foundation
import MixinServices

enum PINVerificationFailureHandler {
    
    static func canHandle(error: MixinAPIError) -> Bool {
        switch error {
        case .tooManyRequests, .incorrectPin:
            return true
        default:
            return false
        }
    }
    
    static func handle(error: MixinAPIError, completion: @escaping (String) -> Void) {
        switch error {
        case .tooManyRequests:
            completion(R.string.localizable.wallet_password_too_many_requests())
        case .incorrectPin:
            AccountAPI.logs(category: "PIN_INCORRECT", limit: 5) { (result) in
                switch result {
                case let .success(logs):
                    var errorCount = 0
                    for log in logs {
                        if -log.createdAt.toUTCDate().timeIntervalSinceNow < 86400 {
                            errorCount += 1
                        }
                    }
                    if errorCount == 5 {
                        completion(R.string.localizable.wallet_password_too_many_requests())
                    } else {
                        completion(R.string.localizable.transfer_error_pin_incorrect_with_times("\(5 - errorCount)"))
                    }
                case .failure:
                    completion(R.string.localizable.error_pin_incorrect())
                }
            }
        default:
            completion(error.localizedDescription)
        }
    }
    
}
