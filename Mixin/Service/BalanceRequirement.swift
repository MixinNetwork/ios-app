import Foundation
import MixinServices

final class BalanceRequirement {
    
    let token: any (ValuableToken & OnChainToken)
    let amount: Decimal
    let isSufficient: Bool
    
    private(set) lazy var fiatMoneyAmount = amount * token.decimalUSDPrice * Currency.current.decimalRate
    private(set) lazy var localizedAmountWithSymbol = CurrencyFormatter.localizedString(
        from: amount,
        format: .precision,
        sign: .never,
        symbol: .custom(token.symbol)
    )
    private(set) lazy var localizedFiatMoneyAmountWithSymbol = CurrencyFormatter.localizedString(
        from: fiatMoneyAmount,
        format: .fiatMoney,
        sign: .never,
        symbol: .currencySymbol
    )
    
    init(token: any OnChainToken & ValuableToken, amount: Decimal) {
        self.token = token
        self.amount = amount
        self.isSufficient = token.decimalBalance >= amount
    }
    
    func merging(with another: BalanceRequirement) -> [BalanceRequirement] {
        if token.assetID == another.token.assetID {
            [BalanceRequirement(token: token, amount: amount + another.amount)]
        } else {
            [self, another]
        }
    }
    
}
