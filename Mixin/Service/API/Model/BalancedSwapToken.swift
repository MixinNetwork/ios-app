import Foundation
import MixinServices

final class BalancedSwapToken: SwapToken, ValuableToken {
    
    let decimalBalance: Decimal
    let decimalUSDPrice: Decimal
    let level: Int
    let isMalicious: Bool
    
    private(set) lazy var decimalUSDBalance = decimalBalance * decimalUSDPrice
    private(set) lazy var localizedFiatMoneyPrice = localizeFiatMoneyPrice()
    private(set) lazy var localizedBalanceWithSymbol = localizeBalanceWithSymbol()
    private(set) lazy var localizedFiatMoneyBalance = localizeFiatMoneyBalance()
    private(set) lazy var estimatedFiatMoneyBalance = estimateFiatMoneyBalance()
    
    init(
        token: SwapToken,
        balance: Decimal,
        usdPrice: Decimal,
        isMalicious: Bool,
        level: Int,
    ) {
        self.decimalBalance = balance
        self.decimalUSDPrice = usdPrice
        self.level = level
        self.isMalicious = isMalicious
        super.init(
            address: token.address,
            assetID: token.assetID,
            decimals: token.decimals,
            name: token.name,
            symbol: token.symbol,
            iconURL: token.iconURL,
            category: token.category,
            chain: token.chain
        )
    }
    
    init?(tokenItem i: any (ValuableToken & OnChainToken)) {
        guard let chain = i.chain else {
            return nil
        }
        self.level = (i as? MixinToken)?.level ?? (i as? Web3Token)?.level ?? 10
        self.decimalBalance = i.decimalBalance
        self.decimalUSDPrice = i.decimalUSDPrice
        self.isMalicious = (i as? MaliciousDistinguishable)?.isMalicious ?? false
        super.init(
            address: i.assetKey,
            assetID: i.assetID,
            decimals: Int(i.precision),
            name: i.name,
            symbol: i.symbol,
            iconURL: i.iconURL,
            category: nil,
            chain: Chain(
                chainID: chain.chainId,
                name: chain.name,
                symbol: chain.symbol,
                icon: chain.iconUrl
            )
        )
    }
    
}
