import Foundation
import MixinServices

extension TIPNode.Error: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .notEnoughPartials:
            return R.string.localizable.not_enough_partials()
        case let .notAllSignersSucceed(numberOfSuccess):
            if numberOfSuccess == 0 {
                return R.string.localizable.all_signer_failure()
            } else {
                return R.string.localizable.not_all_signer_success()
            }
        case .differentIdentity:
            return R.string.localizable.pin_not_same_as_last_time()
        default:
            return R.string.localizable.set_or_update_pin_failed()
        }
    }
    
}
