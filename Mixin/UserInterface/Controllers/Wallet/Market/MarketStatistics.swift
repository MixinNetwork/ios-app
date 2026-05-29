import Foundation
import MixinServices

struct MarketStatistics {
    
    let high24H: String?
    let low24H: String?
    let marketCap: String?
    let fiatMoneyVolume24H: String?
    
    init(market: Market) {
        let high24H: String?
        if let value = Decimal(string: market.high24H, locale: .enUSPOSIX) {
            high24H = CurrencyFormatter.localizedString(
                from: value * Currency.current.decimalRate,
                format: .fiatMoneyPrice,
                sign: .never,
                symbol: .currencySymbol
            )
        } else {
            high24H = nil
        }
        let low24H: String?
        if let value = Decimal(string: market.low24H, locale: .enUSPOSIX) {
            low24H = CurrencyFormatter.localizedString(
                from: value * Currency.current.decimalRate,
                format: .fiatMoneyPrice,
                sign: .never,
                symbol: .currencySymbol
            )
        } else {
            low24H = nil
        }
        let marketCap: String?
        if let value = Decimal(string: market.marketCap, locale: .enUSPOSIX), !value.isZero {
            marketCap = NamedLargeNumberFormatter.string(
                number: value * Currency.current.decimalRate,
                currencyPrefix: .current
            )
        } else {
            marketCap = .notApplicable
        }
        let fiatMoneyVolume24H: String?
        if let totalVolume = Decimal(string: market.totalVolume, locale: .enUSPOSIX) {
            fiatMoneyVolume24H = NamedLargeNumberFormatter.string(
                number: totalVolume * Currency.current.decimalRate,
                currencyPrefix: .current
            )
        } else {
            fiatMoneyVolume24H = nil
        }
        
        self.high24H = high24H
        self.low24H = low24H
        self.marketCap = marketCap
        self.fiatMoneyVolume24H = fiatMoneyVolume24H
    }
    
}
