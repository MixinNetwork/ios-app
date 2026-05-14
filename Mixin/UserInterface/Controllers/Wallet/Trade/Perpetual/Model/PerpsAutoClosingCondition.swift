import Foundation
import MixinServices

final class PerpsAutoClosingCondition {
    
    enum Behavior {
        case takeProfit
        case stopLoss
    }
    
    enum InvalidInputError: Error {
        case mustHigherThan(Decimal)
        case mustLowerThan(Decimal)
    }
    
    let behavior: Behavior
    let basePrice: Decimal
    let side: PerpetualOrderSide
    let leverage: Decimal
    let priceScale: Int
    
    // 0 for invalid
    private(set) var percentage: Decimal
    private(set) var price: Decimal
    
    init(
        behavior: Behavior,
        basePrice: Decimal,
        side: PerpetualOrderSide,
        leverage: Decimal,
        priceScale: Int,
    ) {
        self.behavior = behavior
        self.basePrice = basePrice
        self.side = side
        self.leverage = leverage
        self.priceScale = priceScale
        self.percentage = 0
        self.price = 0
    }
    
    func setPrice(_ price: Decimal) throws(InvalidInputError) {
        guard price > 0 else {
            self.percentage = 0
            self.price = 0
            return
        }
        try check(price: price)
        let percentage = switch side {
        case .long:
            (price - basePrice) * leverage / basePrice
        case .short:
            (price - basePrice) * leverage / basePrice * -1
        }
        self.percentage = percentage
        self.price = price
    }
    
    func setPercentage(_ percentage: Decimal) throws(InvalidInputError) {
        guard percentage != 0 else {
            self.percentage = 0
            self.price = 0
            return
        }
        let price = switch side {
        case .long:
            basePrice * (1 + percentage / leverage)
        case .short:
            basePrice * (1 - percentage / leverage)
        }
        let roundedPrice = withUnsafePointer(to: price) { price in
            var result: Decimal = 0
            NSDecimalRound(&result, price, priceScale, .plain)
            return result
        }
        try check(price: roundedPrice)
        self.percentage = percentage
        self.price = roundedPrice
    }
    
    private func check(price: Decimal) throws(InvalidInputError) {
        let liquidationPrice = PerpetualChangeSimulation.liquidationPrice(
            side: side,
            entryPrice: basePrice,
            leverageMultiplier: leverage
        )
        switch (side, behavior) {
        case (.long, .takeProfit):
            guard price > basePrice else {
                throw InvalidInputError.mustHigherThan(basePrice)
            }
        case (.long, .stopLoss):
            // Available range: (liquidationPrice, basePrice)
            guard price > liquidationPrice else {
                throw InvalidInputError.mustHigherThan(liquidationPrice)
            }
            guard price < basePrice else {
                throw InvalidInputError.mustLowerThan(basePrice)
            }
        case (.short, .takeProfit):
            // Available range: (0, basePrice)
            guard price > 0 else {
                throw InvalidInputError.mustHigherThan(0)
            }
            guard price < basePrice else {
                throw InvalidInputError.mustLowerThan(basePrice)
            }
        case (.short, .stopLoss):
            // Available range: (basePrice, liquidationPrice)
            guard price > basePrice else {
                throw InvalidInputError.mustHigherThan(basePrice)
            }
            guard price < liquidationPrice else {
                throw InvalidInputError.mustLowerThan(liquidationPrice)
            }
        }
    }
    
}

extension PerpsAutoClosingCondition {
    
    static func maxChange(
        margin: Decimal,
        side: PerpetualOrderSide,
        leverage: Decimal,
        behavior: PerpsAutoClosingCondition.Behavior,
        currentPrice: Decimal,
        closingPrice: Decimal,
    ) -> String {
        assert(margin != 0, "Only results 0")
        let percentage = switch side {
        case .long:
            (closingPrice - currentPrice) * leverage / currentPrice
        case .short:
            (closingPrice - currentPrice) * leverage / currentPrice * -1
        }
        var marginChange = margin * percentage
        if behavior == .stopLoss, marginChange < 0 {
            marginChange = max(-margin, marginChange)
        }
        var localizedChange = CurrencyFormatter.localizedString(
            from: marginChange * Currency.current.decimalRate,
            format: .fiatMoneyPretty,
            sign: .always,
            symbol: .currencySymbol
        )
        switch behavior {
        case .takeProfit:
            localizedChange += " ("
            + PercentageFormatter.string(
                from: percentage,
                format: .pretty,
                sign: .never
            )
            + ")"
        case .stopLoss:
            break
        }
        return localizedChange
    }
    
    func maxChange(margin: Decimal) -> String {
        assert(margin != 0, "Only results 0")
        var maxChange = CurrencyFormatter.localizedString(
            from: margin * percentage * Currency.current.decimalRate,
            format: .fiatMoneyPretty,
            sign: .always,
            symbol: .currencySymbol
        )
        switch behavior {
        case .takeProfit:
            maxChange += " (" + PercentageFormatter.string(
                from: percentage,
                format: .pretty,
                sign: .never
            ) + ")"
        case .stopLoss:
            break
        }
        return maxChange
    }
    
}
