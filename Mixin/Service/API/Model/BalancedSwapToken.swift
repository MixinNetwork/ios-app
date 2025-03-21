import Foundation
import MixinServices

final class BalancedSwapToken: SwapToken, ValuableToken {
    
    let decimalBalance: Decimal
    let decimalUSDPrice: Decimal
    
    private(set) lazy var decimalUSDBalance = decimalBalance * decimalUSDPrice
    private(set) lazy var localizedFiatMoneyPrice = localizeFiatMoneyPrice()
    private(set) lazy var localizedBalanceWithSymbol = localizeBalanceWithSymbol()
    private(set) lazy var estimatedFiatMoneyBalance = estimateFiatMoneyBalance()
    
    init(token: SwapToken, balance: Decimal, usdPrice: Decimal) {
        self.decimalBalance = balance
        self.decimalUSDPrice = usdPrice
        super.init(
            address: token.address,
            assetID: token.assetID,
            decimals: token.decimals,
            name: token.name,
            symbol: token.symbol,
            iconURL: token.iconURL,
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
            iconURL: i.iconURL,
            chain: Chain(
                chainID: chain.chainId,
                name: chain.name,
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
