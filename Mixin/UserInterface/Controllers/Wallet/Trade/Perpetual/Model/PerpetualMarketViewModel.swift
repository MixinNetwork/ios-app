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
    let fundingRate: String
    let change: String
    let changeColor: MarketColor
    let userDisplayPriceFormatStyle: Decimal.FormatStyle.Currency
    let description: String?
    let nextFundingAt: Date
    let openInterest: String?
    
    init(market m: PerpetualMarket) {
        let userDisplayPriceFormatStyle = PerpetualMarket.userDisplayPriceFormatStyle(scale: m.priceScale)
        let decimalFundingRate = Decimal(string: m.fundingRate, locale: .enUSPOSIX)
        let openInterest = Decimal(string: m.openInterest, locale: .enUSPOSIX)
        
        self.market = m
        self.iconURL = URL(string: m.iconURL)
        self.maxLeverageMultiplier = Decimal(m.leverage)
        self.leverage = PerpetualLeverage.stringRepresentation(multiplier: m.leverage)
        self.decimalPrice = m.decimalPrice
        self.price = m.localizedPrice
        self.volume = m.prettyVolume
        self.fundingRate = if let decimalFundingRate {
            PercentageFormatter.string(
                from: decimalFundingRate,
                format: .precision,
                sign: .whenNegative
            )
        } else {
            m.fundingRate
        }
        self.change = m.changePercentage
        self.changeColor = m.decimalChange >= 0 ? .rising : .falling
        self.userDisplayPriceFormatStyle = userDisplayPriceFormatStyle
        if let description = m.descriptions?[Market.languageIdentifier],
           !description.isEmpty
        {
            self.description = description
        } else {
            self.description = nil
        }
        self.nextFundingAt = m.nextFundingAt.toUTCDate()
        if let openInterest, openInterest != 0 {
            self.openInterest = NamedLargeNumberFormatter.string(
                number: openInterest,
                currency: .usd
            )
        } else {
            self.openInterest = nil
        }
    }
    
}
