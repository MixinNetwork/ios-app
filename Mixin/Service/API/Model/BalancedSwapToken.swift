import Foundation
import MixinServices

final class BalancedSwapToken: SwapToken, Token {
    
    let decimalBalance: Decimal
    let decimalUSDPrice: Decimal
    
    private(set) lazy var decimalUSDBalance = decimalBalance * decimalUSDPrice
    private(set) lazy var localizedBalanceWithSymbol = CurrencyFormatter.localizedString(
        from: decimalBalance,
        format: .precision,
        sign: .never,
        symbol: .custom(symbol)
    )
    
    private(set) lazy var localizedFiatMoneyPrice = localizeFiatMoneyPrice()
    
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
    
    init?(tokenItem i: MixinTokenItem) {
        guard let chain = i.chain else {
            return nil
        }
        self.decimalBalance = i.decimalBalance
        self.decimalUSDPrice = i.decimalUSDPrice
        super.init(
            address: "",
            assetID: i.assetID,
            decimals: 0,
            name: i.name,
            symbol: i.symbol,
            icon: i.iconURL,
            chain: Chain(
                chainID: chain.chainId,
                name: chain.name,
                decimals: 0,
                symbol: chain.symbol,
                icon: chain.iconUrl
            )
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
        }
    }
    
}
