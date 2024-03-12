import Foundation
import MixinServices

enum PINVerificationFailureHandler {
    
    static func canHandle(error: MixinAPIError) -> Bool {
        switch error {
        case MixinAPIResponseError.tooManyRequests, .incorrectPin, .pinEncryptionFailed:
            return true
        default:
            return false
        }
    }
    
    static func handle(error: MixinAPIError, completion: @escaping (String) -> Void) {
        switch error {
        case MixinAPIResponseError.tooManyRequests:
            completion(R.string.localizable.error_pin_check_too_many_request())
        case .incorrectPin:
            AccountAPI.logs(category: .incorrectPin, limit: 5) { (result) in
                switch result {
                case let .success(logs):
                    var errorCount = 0
                    for log in logs {
                        if -log.createdAt.toUTCDate().timeIntervalSinceNow < 86400 {
                            errorCount += 1
                        }
                    }
                    if errorCount == 5 {
                        completion(R.string.localizable.error_pin_check_too_many_request())
                    } else {
                        completion(R.string.localizable.transfer_error_pin_incorrect_with_times("\(5 - errorCount)"))
                    }
                case .failure:
                    completion(error.localizedDescription)
                }
            }
        case .pinEncryptionFailed(let error as TIPNode.Error):
            completion(error.localizedDescription)
        default:
            completion(error.localizedDescription)
        }
    }
    
    static func handle(error: MixinAPIError) async -> String {
        await withCheckedContinuation { continuation in
            handle(error: error) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
}
