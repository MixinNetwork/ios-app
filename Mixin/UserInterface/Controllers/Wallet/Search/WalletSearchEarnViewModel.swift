import Foundation
import MixinServices

struct WalletSearchEarnViewModel {
    
    let productionID: String
    let token: MixinTokenItem
    let symbol: String
    let value: String
    let apy: String?
    
    init(product: EarnProduct, token: MixinTokenItem) {
        self.productionID = product.productionID
        self.token = token
        self.symbol = token.symbol
        let principal = Decimal(string: product.account.totalPrincipal, locale: .enUSPOSIX) ?? 0
        let earnings = Decimal(string: product.account.redeemableEarnings, locale: .enUSPOSIX) ?? 0
        self.value = CurrencyFormatter.localizedString(
            from: principal + earnings,
            format: .precision,
            sign: .never,
            symbol: .custom(token.symbol),
        )
        self.apy = if let rate = product.annualRates.compactMap({ Decimal(string: $0, locale: .enUSPOSIX) }).max() {
            R.string.localizable.cash_account_apy(
                PercentageFormatter.string(from: rate, format: .pretty, sign: .never)
            )
        } else {
            nil
        }
    }
    
}
