import Foundation
import MixinServices

final class BalancedSwapToken: SwapToken {
    
    let decimalBalance: Decimal
    let decimalUSDPrice: Decimal
    
    private(set) lazy var localizedBalanceWithSymbol = CurrencyFormatter.localizedString(
        from: decimalBalance,
        format: .precision,
        sign: .never,
        symbol: .custom(symbol)
    )
    
    init(token: SwapToken, balance: Decimal, usdPrice: Decimal) {
        self.decimalBalance = balance
        self.decimalUSDPrice = usdPrice
        super.init(
            address: token.address,
            assetID: token.assetID,
            decimals: token.decimals,
            name: token.name,
            symbol: token.symbol,
            icon: token.icon,
            chain: token.chain
        )
    }
    
}

extension BalancedSwapToken {
    
    static func fillBalance(swappableTokens: [SwapToken]) -> [BalancedSwapToken] {
        let ids = swappableTokens.map(\.assetID)
        let tokenItems = TokenDAO.shared.tokenItems(with: ids)
            .reduce(into: [:]) { result, item in
                result[item.assetID] = item
            }
        return swappableTokens.map { token in
            if let item = tokenItems[token.assetID] {
                BalancedSwapToken(token: token, balance: item.decimalBalance, usdPrice: item.decimalUSDPrice)
            } else {
                BalancedSwapToken(token: token, balance: 0, usdPrice: 0)
            }
        }.sorted { (one, another) in
            let left = (one.decimalBalance * one.decimalUSDPrice, one.decimalBalance, one.decimalUSDPrice)
            let right = (another.decimalBalance * another.decimalUSDPrice, another.decimalBalance, another.decimalUSDPrice)
            return left > right
        }
    }
    
}
