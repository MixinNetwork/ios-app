import Foundation
import MixinServices

final class MarketIndicator {
    
    let marketCap: String
    let marketCapChange: String
    let marketCapColor: MarketColor
    let volume: String
    let volumeChange: String
    let volumeColor: MarketColor
    let btcPercentage: Double
    let btcPercentageString: String
    let otherPercentageString: String
    
    init(market: GlobalMarket) {
        self.marketCap = NamedLargeNumberFormatter.string(
            number: market.marketCap * Currency.current.decimalRate,
            currency: .current,
        )
        self.marketCapChange = NumberFormatter.percentage.string(
            decimal: market.marketCapChangePercentage / 100
        ) ?? "-"
        self.marketCapColor = .byValue(market.marketCapChangePercentage)
        
        self.volume = NamedLargeNumberFormatter.string(
            number: market.volume * Currency.current.decimalRate,
            currency: .current,
        )
        self.volumeChange = NumberFormatter.percentage.string(
            decimal: market.volumeChangePercentage / 100
        ) ?? "-"
        self.volumeColor = .byValue(market.volumeChangePercentage)
        
        let btcPercentage = withUnsafePointer(to: market.dominancePercentage / 100) { percentage in
            var result = Decimal()
            NSDecimalRound(&result, percentage, 4, .plain)
            return result
        }
        self.btcPercentage = NSDecimalNumber(decimal: btcPercentage).doubleValue
        self.btcPercentageString = NumberFormatter.percentage.string(decimal: btcPercentage) ?? "-"
        
        let otherPercentage = 1 - btcPercentage
        self.otherPercentageString = NumberFormatter.percentage.string(decimal: otherPercentage) ?? "-"
    }
    
}

extension MarketIndicator: Equatable {
    
    static func == (lhs: MarketIndicator, rhs: MarketIndicator) -> Bool {
        lhs === rhs
    }
    
}

extension MarketIndicator: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
}
