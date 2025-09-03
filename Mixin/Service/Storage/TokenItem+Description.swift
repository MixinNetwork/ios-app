import Foundation
import MixinServices

extension MixinTokenItem {
    
    var depositTips: String {
        switch chainID {
        case ChainID.bitcoin:
            return R.string.localizable.deposit_tip_btc() + R.string.localizable.deposit_confirmation_count(confirmations)
        case ChainID.eos:
            return R.string.localizable.deposit_tip_eos() + R.string.localizable.deposit_confirmation_count(confirmations)
        case ChainID.ethereum:
            return R.string.localizable.deposit_tip_eth() + R.string.localizable.deposit_confirmation_count(confirmations)
        case ChainID.tron:
            return R.string.localizable.deposit_tip_trx() + R.string.localizable.deposit_confirmation_count(confirmations)
        default:
            return R.string.localizable.deposit_tip_common(symbol) + R.string.localizable.deposit_confirmation_count(confirmations)
        }
    }
    
}
