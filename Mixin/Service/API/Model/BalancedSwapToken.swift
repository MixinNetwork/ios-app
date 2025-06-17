import Foundation
import MixinServices

final class BalancedSwapToken: SwapToken, ValuableToken {
    
    let decimalBalance: Decimal
    let decimalUSDPrice: Decimal
    
    private(set) lazy var decimalUSDBalance = decimalBalance * decimalUSDPrice
    private(set) lazy var localizedFiatMoneyPrice = localizeFiatMoneyPrice()
    private(set) lazy var localizedBalanceWithSymbol = localizeBalanceWithSymbol()
    private(set) lazy var localizedFiatMoneyBalance = localizeFiatMoneyBalance()
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
    
    init?(tokenItem i: any (ValuableToken & OnChainToken)) {
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
    
    static func fillMixinBalance(swappableTokens: [SwapToken]) -> [BalancedSwapToken] {
        fillBalance(swappableTokens: swappableTokens, walletID: nil)
    }
    
    static func fillWeb3Balance(swappableTokens: [SwapToken], walletID: String) -> [BalancedSwapToken] {
        fillBalance(swappableTokens: swappableTokens, walletID: walletID)
    }

    private static func fillBalance(swappableTokens: [SwapToken], walletID: String?) -> [BalancedSwapToken] {
        let ids = swappableTokens.map(\.assetID)
        let tokenItems: [ValuableToken] = if let walletID {
            Web3TokenDAO.shared.tokens(walletID: walletID, ids: ids)
        } else {
            TokenDAO.shared.tokenItems(with: ids)
        }
        let tokenMaps = tokenItems.reduce(into: [:]) { result, item in
            result[item.assetID] = item
        }
        return swappableTokens.map { token in
            if let item = tokenMaps[token.assetID] {
                BalancedSwapToken(token: token, balance: item.decimalBalance, usdPrice: item.decimalUSDPrice)
            } else {
                BalancedSwapToken(token: token, balance: 0, usdPrice: 0)
            }
        }
    }
    
}
