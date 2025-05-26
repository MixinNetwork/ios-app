import Foundation
import MixinServices

struct WithdrawFeeItem {
    
    let amount: Decimal
    let tokenItem: MixinTokenItem
    let localizedAmountWithSymbol: String
    
    init?(amountString: String, tokenItem: MixinTokenItem) {
        guard let amount = Decimal(string: amountString, locale: .enUSPOSIX) else {
            return nil
        }
        self.init(amount: amount, tokenItem: tokenItem)
    }
    
    init(amount: Decimal, tokenItem: MixinTokenItem) {
        self.amount = amount
        self.tokenItem = tokenItem
        self.localizedAmountWithSymbol = CurrencyFormatter.localizedString(
            from: amount,
            format: .precision,
            sign: .never,
            symbol: .custom(tokenItem.symbol)
        )
    }
    
}
