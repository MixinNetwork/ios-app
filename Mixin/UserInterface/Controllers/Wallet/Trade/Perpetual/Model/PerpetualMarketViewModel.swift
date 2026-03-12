import Foundation
import MixinServices

struct PerpetualMarketViewModel {
    
    let market: PerpetualMarket
    let iconURL: URL?
    let maxLeverageMultiplier: Decimal
    let leverage: String
    let decimalPrice: Decimal
    let price: String
    let volume: String
    let amount: String
    let fundingRate: String
    let change: String
    let changeColor: MarketColor
    
    init?(market m: PerpetualMarket) {
        guard
            let decimalPrice = Decimal(string: m.markPrice, locale: .enUSPOSIX),
            let change = Decimal(string: m.change, locale: .enUSPOSIX),
            let changePercentage = NumberFormatter.percentage.string(decimal: change),
            let decimalVolume = Decimal(string: m.volume, locale: .enUSPOSIX),
            let decimalAmount = Decimal(string: m.amount, locale: .enUSPOSIX),
            let decimalFundingRate = Decimal(string: m.fundingRate, locale: .enUSPOSIX)
        else {
            return nil
        }
        self.market = m
        self.iconURL = URL(string: m.iconURL)
        self.maxLeverageMultiplier = Decimal(m.leverage)
        self.leverage = PerpetualLeverage.stringRepresentation(multiplier: m.leverage)
        self.decimalPrice = decimalPrice
        self.price = CurrencyFormatter.localizedString(
            from: decimalPrice * Currency.current.decimalRate,
            format: .precision,
            sign: .never,
            symbol: .currencySymbol
        )
        self.volume = NamedLargeNumberFormatter.string(
            number: decimalVolume,
            currencyPrefix: true
        ) ?? m.volume
        self.amount = NamedLargeNumberFormatter.string(
            number: decimalAmount,
            currencyPrefix: true
        ) ?? m.amount
        self.fundingRate = PercentageFormatter.string(
            from: decimalFundingRate,
            format: .precision,
            sign: .whenNegative
        )
        self.change = changePercentage
        self.changeColor = change >= 0 ? .rising : .falling
    }
    
}
