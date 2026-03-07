import Foundation
import MixinServices

struct PerpetualMarketViewModel {
    
    let market: PerpetualMarket
    let product: String
    let iconURL: URL?
    let symbol: String
    let maxLeverageMultiplier: Decimal
    let leverage: String
    let decimalPrice: Decimal
    let price: String
    let volume: String
    let change: String
    let changeColor: MarketColor
    
    init?(market m: PerpetualMarket) {
        guard
            let decimalPrice = Decimal(string: m.markPrice, locale: .enUSPOSIX),
            let change = Decimal(string: m.change, locale: .enUSPOSIX),
            let changePercentage = NumberFormatter.percentage.string(decimal: change / 100)
        else {
            return nil
        }
        self.market = m
        self.product = market.symbol
        self.iconURL = URL(string: m.iconURL)
        self.symbol = m.tokenSymbol
        self.maxLeverageMultiplier = Decimal(m.leverage)
        self.leverage = PerpetualLeverage.stringRepresentation(multiplier: m.leverage)
        self.decimalPrice = decimalPrice
        self.price = CurrencyFormatter.localizedString(
            from: decimalPrice * Currency.current.decimalRate,
            format: .precision,
            sign: .never,
            symbol: .currencySymbol
        )
        self.volume = m.volume
        self.change = changePercentage
        self.changeColor = change >= 0 ? .rising : .falling
    }
    
}
