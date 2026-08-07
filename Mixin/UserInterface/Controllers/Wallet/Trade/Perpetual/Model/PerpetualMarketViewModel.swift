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
    
    init?(market m: PerpetualMarket) {
        guard let decimalFundingRate = Decimal(string: m.fundingRate, locale: .enUSPOSIX) else {
            return nil
        }
        let userDisplayPriceFormatStyle = PerpetualMarket.userDisplayPriceFormatStyle(scale: m.priceScale)
        
        self.market = m
        self.iconURL = URL(string: m.iconURL)
        self.maxLeverageMultiplier = Decimal(m.leverage)
        self.leverage = PerpetualLeverage.stringRepresentation(multiplier: m.leverage)
        self.decimalPrice = m.decimalPrice
        self.price = m.localizedPrice
        self.volume = m.prettyVolume
        self.fundingRate = PercentageFormatter.string(
            from: decimalFundingRate,
            format: .precision,
            sign: .whenNegative
        )
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
    }
    
}
