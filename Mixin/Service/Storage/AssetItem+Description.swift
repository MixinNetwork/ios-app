import Foundation
import MixinServices

extension AssetItem {
    
    var depositTips: String {
        switch chainId {
        case "c6d0c728-2624-429b-8e0d-d9d19b6592fa":
            return R.string.localizable.deposit_tip_btc() + R.string.localizable.deposit_confirmation_count(confirmations)
        case "6cfe566e-4aad-470b-8c9a-2fd35b49c68d":
            return R.string.localizable.deposit_tip_eos() + R.string.localizable.deposit_confirmation_count(confirmations)
        case "43d61dcd-e413-450d-80b8-101d5e903357":
            return R.string.localizable.deposit_tip_eth() + R.string.localizable.deposit_confirmation_count(confirmations)
        case "25dabac5-056a-48ff-b9f9-f67395dc407c":
            return R.string.localizable.deposit_tip_trx() + R.string.localizable.deposit_confirmation_count(confirmations)
        default:
            return R.string.localizable.deposit_tip_common(symbol) + R.string.localizable.deposit_confirmation_count(confirmations)
        }
    }
    
    var memoLabel: String {
        return usesTag ? R.string.localizable.tag() : R.string.localizable.memo()
    }
    
}
