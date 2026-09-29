import Foundation
import MixinServices

final class PerpsAutoClosingCondition {
    
    enum Behavior {
        case takeProfit
        case stopLoss
    }
    
    enum OrderState {
        case draft
        case open(entryPrice: Decimal, quantity: Decimal)
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
    
    private let orderState: OrderState
    private let margin: Decimal
    private let priceChangeForFullMargin: Decimal
    private let percentageDerivationScale = 2
    
    init(
        behavior: Behavior,
        side: PerpetualOrderSide,
        leverage: Decimal,
        margin: Decimal,
        marketViewModel: PerpetualMarketViewModel,
        orderState: OrderState,
        liquidationPrice: Decimal,
    ) {
        let entryPrice: Decimal = switch orderState {
        case .draft:
            marketViewModel.decimalPrice
        case .open(let entryPrice, _):
            entryPrice
        }
        self.behavior = behavior
        self.side = side
        self.leverage = leverage
        self.orderState = orderState
        self.margin = margin
        self.priceChangeForFullMargin = switch orderState {
        case .draft:
            entryPrice / leverage
        case .open(_, let quantity):
            margin / quantity
        }
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
        let longPercentage = (price - entryPrice) / priceChangeForFullMargin
        let percentage = side == .long ? longPercentage : -longPercentage
        let roundedPercentage = withUnsafePointer(to: percentage * 100) { percentage in
            var result: Decimal = 0
            NSDecimalRound(&result, percentage, percentageDerivationScale, .plain)
            return result / 100
        }
        self.percentage = roundedPercentage
        self.price = price
    }
    
    func setPercentage(_ percentage: Decimal) throws(InvalidInputError) {
        if let roundedPrice = roundedPrice(percentage: percentage) {
            try check(price: roundedPrice)
            self.percentage = percentage
            self.price = roundedPrice
        } else {
            self.percentage = 0
            self.price = 0
        }
    }
    
    func roundedPrice(percentage: Decimal) -> Decimal? {
        guard percentage != 0 else {
            return nil
        }
        let priceChange = percentage * priceChangeForFullMargin
        let price = side == .long ? entryPrice + priceChange : entryPrice - priceChange
        let roundedPrice = withUnsafePointer(to: price) { price in
            var result: Decimal = 0
            NSDecimalRound(&result, price, priceScale, .plain)
            return result
        }
        return roundedPrice
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
    
    func maxChange() -> String {
        assert(margin != 0, "Only results 0")
        let pnl: Decimal = switch orderState {
        case .draft:
            margin * percentage
        case .open(_, let quantity):
            (price - entryPrice) * quantity * (side == .long ? 1 : -1)
        }
        var maxChange = CurrencyFormatter.localizedString(
            from: pnl,
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
