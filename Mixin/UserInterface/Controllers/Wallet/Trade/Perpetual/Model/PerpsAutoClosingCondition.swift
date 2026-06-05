import Foundation
import MixinServices

final class PerpsAutoClosingCondition {
    
    enum Behavior {
        case takeProfit
        case stopLoss
    }
    
    enum OrderState {
        case draft
        case open(entryPrice: Decimal)
    }
    
    enum InvalidInputError: Error {
        case mustHigherThan(Decimal)
        case mustLowerThan(Decimal)
    }
    
    let behavior: Behavior
    let side: PerpetualOrderSide
    let leverage: Decimal
    let priceScale: Int
    let entryPrice: Decimal
    let currentPrice: Decimal
    let liquidationPrice: Decimal
    
    // 0 for invalid
    private(set) var percentage: Decimal
    private(set) var price: Decimal
    
    private let percentageDerivationScale = 2
    
    init(
        behavior: Behavior,
        side: PerpetualOrderSide,
        leverage: Decimal,
        marketViewModel: PerpetualMarketViewModel,
        orderState: OrderState,
        liquidationPrice: Decimal,
    ) {
        let entryPrice: Decimal = switch orderState {
        case .draft:
            marketViewModel.decimalPrice
        case .open(let entryPrice):
            entryPrice
        }
        self.behavior = behavior
        self.side = side
        self.leverage = leverage
        self.priceScale = marketViewModel.market.priceScale
        self.entryPrice = entryPrice
        self.currentPrice = marketViewModel.decimalPrice
        self.liquidationPrice = liquidationPrice
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
            (price - entryPrice) * leverage / entryPrice
        case .short:
            (price - entryPrice) * leverage / entryPrice * -1
        }
        let roundedPercentage = withUnsafePointer(to: percentage * 100) { percentage in
            var result: Decimal = 0
            NSDecimalRound(&result, percentage, percentageDerivationScale, .plain)
            return result / 100
        }
        self.percentage = roundedPercentage
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
            entryPrice * (1 + percentage / leverage)
        case .short:
            entryPrice * (1 - percentage / leverage)
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
        switch (side, behavior) {
        case (.long, .takeProfit):
            guard price > entryPrice else {
                // To be a profit
                throw .mustHigherThan(entryPrice)
            }
            guard price > currentPrice else {
                // Avoid immediate execution
                throw .mustHigherThan(currentPrice)
            }
        case (.long, .stopLoss):
            guard price < currentPrice else {
                // Product requirements
                throw .mustLowerThan(currentPrice)
            }
            guard price > liquidationPrice else {
                // To reduce loss
                throw .mustHigherThan(liquidationPrice)
            }
        case (.short, .takeProfit):
            guard price < entryPrice else {
                // To be a profit
                throw .mustLowerThan(entryPrice)
            }
            guard price < currentPrice else {
                // Avoid immediate execution
                throw .mustLowerThan(currentPrice)
            }
        case (.short, .stopLoss):
            guard price > currentPrice else {
                // Product requirements
                throw .mustHigherThan(currentPrice)
            }
            guard price < liquidationPrice else {
                // To reduce loss
                throw .mustLowerThan(liquidationPrice)
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
            from: marginChange,
            format: .fiatMoneyPretty,
            sign: .always,
            symbol: .dollarSign
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
            from: margin * percentage,
            format: .fiatMoneyPretty,
            sign: .always,
            symbol: .dollarSign
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
