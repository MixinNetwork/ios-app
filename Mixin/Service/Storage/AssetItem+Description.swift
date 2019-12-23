import Foundation

extension AssetItem {
    
    var depositTips: String {
        switch chainId {
        case "c6d0c728-2624-429b-8e0d-d9d19b6592fa":
            return R.string.localizable.wallet_deposit_btc() + Localized.WALLET_DEPOSIT_CONFIRMATIONS(confirmations: confirmations)
        case "6cfe566e-4aad-470b-8c9a-2fd35b49c68d":
            return R.string.localizable.wallet_deposit_eos() + Localized.WALLET_DEPOSIT_CONFIRMATIONS(confirmations: confirmations)
        case "43d61dcd-e413-450d-80b8-101d5e903357":
            return R.string.localizable.wallet_deposit_eth() + Localized.WALLET_DEPOSIT_CONFIRMATIONS(confirmations: confirmations)
        case "25dabac5-056a-48ff-b9f9-f67395dc407c":
            return R.string.localizable.wallet_deposit_trx() + Localized.WALLET_DEPOSIT_CONFIRMATIONS(confirmations: confirmations)
        default:
            return R.string.localizable.wallet_deposit_other(symbol) + Localized.WALLET_DEPOSIT_CONFIRMATIONS(confirmations: confirmations)
        }
    }
    
    var memoLabel: String {
        return isUseTag ? R.string.localizable.wallet_address_tag() : R.string.localizable.wallet_address_memo()
    }
    
}
