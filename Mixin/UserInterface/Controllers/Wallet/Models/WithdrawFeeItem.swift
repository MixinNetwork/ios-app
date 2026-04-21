import Foundation
import MixinServices

struct WithdrawFeeItem: NetworkFee {
    
    let token: MixinTokenItem
    let amount: Decimal
    let localizedAmountWithSymbol: String
    
    var assetID: String {
        token.assetID
    }
    
    init?(tokenItem: MixinTokenItem, amountString: String) {
        guard let amount = Decimal(string: amountString, locale: .enUSPOSIX) else {
            return nil
        }
        self.init(tokenItem: tokenItem, amount: amount)
    }
    
    init(tokenItem: MixinTokenItem, amount: Decimal) {
        self.amount = amount
        self.token = tokenItem
        self.localizedAmountWithSymbol = CurrencyFormatter.localizedString(
            from: amount,
            format: .precision,
            sign: .never,
            symbol: .custom(tokenItem.symbol)
        )
    }
    
}
