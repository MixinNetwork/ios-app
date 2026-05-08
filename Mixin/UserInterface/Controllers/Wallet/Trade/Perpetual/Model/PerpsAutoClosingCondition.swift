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
        case mustBetween(lowest: Decimal, highest: Decimal)
    }
    
    let behavior: Behavior
    let basePrice: Decimal
    let side: PerpetualOrderSide
    let leverage: Decimal
    
    // 0 for invalid
    private(set) var percentage: Decimal
    private(set) var price: Decimal
    
    init(
        behavior: Behavior,
        basePrice: Decimal,
        side: PerpetualOrderSide,
        leverage: Decimal
    ) {
        self.behavior = behavior
        self.basePrice = basePrice
        self.side = side
        self.leverage = leverage
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
        self.percentage = switch side {
        case .long:
            (price - basePrice) * leverage / basePrice
        case .short:
            (price - basePrice) * leverage / basePrice * -1
        }
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
        try check(price: price)
        self.percentage = percentage
        self.price = price
    }
    
    func maxChange(margin: Decimal) -> String? {
        guard margin != 0 else {
            return nil
        }
        let precision = margin.numberOfSignificantFractionalDigits + 1
        let maxChange = (margin * percentage).formatted(
            Decimal.FormatStyle.Currency
                .currency(code: "USD")
                .presentation(.narrow)
                .sign(strategy: .always())
                .precision(
                    .fractionLength(0...precision)
                )
        )
        switch behavior {
        case .takeProfit:
            return maxChange
            + " ("
            + PercentageFormatter.string(
                from: percentage,
                format: .pretty,
                sign: .never
            )
            + ")"
        case .stopLoss:
            return maxChange
        }
    }
    
    private func check(price: Decimal) throws(InvalidInputError) {
        switch (side, behavior) {
        case (.long, .takeProfit):
            if price <= basePrice {
                throw InvalidInputError.mustHigherThan(basePrice)
            }
        case (.long, .stopLoss):
            if price >= basePrice {
                throw InvalidInputError.mustLowerThan(basePrice)
            }
        case (.short, .takeProfit):
            if price >= basePrice {
                throw InvalidInputError.mustLowerThan(basePrice)
            }
        case (.short, .stopLoss):
            if price <= basePrice {
                throw InvalidInputError.mustHigherThan(basePrice)
            }
        }
    }
    
}

extension PerpsAutoClosingCondition {
    
    static var canonicalFormatStyle: Decimal.FormatStyle {
        Decimal.FormatStyle.number
            .locale(.enUSPOSIX)
            .grouping(.never)
            .sign(strategy: .never)
            .rounded(rule: .towardZero)
            .precision(.fractionLength(0...8))
    }
    
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
        let precision = margin.numberOfSignificantFractionalDigits + 1
        let maxChange = (margin * percentage).formatted(
            Decimal.FormatStyle.Currency
                .currency(code: "USD")
                .presentation(.narrow)
                .sign(strategy: .always())
                .precision(
                    .fractionLength(0...precision)
                )
        )
        switch behavior {
        case .takeProfit:
            return maxChange
            + " ("
            + PercentageFormatter.string(
                from: percentage,
                format: .pretty,
                sign: .never
            )
            + ")"
        case .stopLoss:
            return maxChange
        }
    }
    
}
