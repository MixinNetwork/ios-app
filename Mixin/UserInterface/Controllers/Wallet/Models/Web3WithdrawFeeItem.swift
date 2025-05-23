import Foundation
import MixinServices

struct Web3WithdrawFeeItem {
    
    let amount: Decimal
    let tokenItem: Web3TokenItem
    let localizedAmountWithSymbol: String
    
    init(amount: Decimal, tokenItem: Web3TokenItem) {
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
