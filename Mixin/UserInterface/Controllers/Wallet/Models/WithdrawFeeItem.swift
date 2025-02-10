import Foundation
import MixinServices

struct WithdrawFeeItem {
    
    let amount: Decimal
    let tokenItem: TokenItem
    let localizedAmountWithSymbol: String
    
    init?(amountString: String, tokenItem: TokenItem) {
        guard let amount = Decimal(string: amountString, locale: .enUSPOSIX) else {
            return nil
        }
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
