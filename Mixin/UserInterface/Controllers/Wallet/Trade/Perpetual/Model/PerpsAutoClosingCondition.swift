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
        case unavailableFeeRate
    }
    
    let behavior: Behavior
    let side: PerpetualOrderSide
    let leverage: Decimal
    let priceScale: Int
    let entryPrice: Decimal
    let currentPrice: Decimal
    let liquidationPrice: Decimal
    
    private(set) var percentage: Decimal
    // 0 for invalid
    private(set) var price: Decimal
    
    private let orderState: OrderState
    private let margin: Decimal
    private let priceChangeForFullMargin: Decimal
    private let feeRate: Decimal?
    
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
            marketViewModel.decimalLastPrice
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
            quantity == 0 ? 0 : margin / quantity
        }
        self.feeRate = marketViewModel.market.decimalFeeRate
        self.priceScale = marketViewModel.market.priceScale
        self.entryPrice = entryPrice
        self.currentPrice = marketViewModel.decimalLastPrice
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
        guard let feeRate else {
            throw .unavailableFeeRate
        }
        try check(price: price)
        let priceChange = (price - entryPrice) * (side == .long ? 1 : -1)
        self.percentage = priceChangeForFullMargin > 0
            ? (priceChange - (entryPrice + price) * feeRate) / priceChangeForFullMargin
            : 0
        self.price = price
    }
    
    func setPercentage(_ percentage: Decimal) throws(InvalidInputError) {
        guard feeRate != nil else {
            throw .unavailableFeeRate
        }
        if let price = triggerPrice(percentage: percentage),
           let roundedPrice = roundedPrice(percentage: percentage)
        {
            try check(price: price)
            try check(price: roundedPrice)
            self.percentage = percentage
            self.price = price
        } else {
            self.percentage = 0
            self.price = 0
        }
    }
    
    func roundedPrice(percentage: Decimal) -> Decimal? {
        guard let price = triggerPrice(percentage: percentage) else {
            return nil
        }
        let roundedPrice = withUnsafePointer(to: price) { price in
            var result: Decimal = 0
            NSDecimalRound(&result, price, priceScale, .plain)
            return result
        }
        return roundedPrice
    }
    
    private func triggerPrice(percentage: Decimal) -> Decimal? {
        guard let feeRate, feeRate >= 0, feeRate < 1, entryPrice > 0 else {
            return nil
        }
        let profitPerQuantity = percentage * priceChangeForFullMargin
        return switch side {
        case .long:
            (profitPerQuantity + entryPrice * (1 + feeRate)) / (1 - feeRate)
        case .short:
            (entryPrice * (1 - feeRate) - profitPerQuantity) / (1 + feeRate)
        }
    }
    
    private func check(price: Decimal) throws(InvalidInputError) {
        guard let breakEvenPrice = triggerPrice(percentage: 0) else {
            throw .unavailableFeeRate
        }
        switch (side, behavior) {
        case (.long, .takeProfit):
            guard price > breakEvenPrice else {
                // To be a profit after opening and closing fees
                throw .mustHigherThan(breakEvenPrice)
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
            guard price < breakEvenPrice else {
                // To be a profit after opening and closing fees
                throw .mustLowerThan(breakEvenPrice)
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
        feeRate: Decimal?,
    ) -> String {
        assert(margin != 0, "Only results 0")
        guard let feeRate, currentPrice > 0 else {
            return "-"
        }
        let quantity = abs(margin * leverage / currentPrice)
        let marginChange = netPNL(
            side: side,
            quantity: quantity,
            entryPrice: currentPrice,
            closingPrice: closingPrice,
            feeRate: feeRate,
        )
        let percentage = margin != 0 ? marginChange / margin : 0
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
                sign: .whenNegative
            )
            + ")"
        case .stopLoss:
            break
        }
        return localizedChange
    }
    
    func maxChange() -> (value: Decimal, localized: String) {
        assert(margin != 0, "Only results 0")
        guard let feeRate else {
            return (value: 0, localized: "-")
        }
        let pnl: Decimal = switch orderState {
        case .draft:
            margin * percentage
        case .open(_, let quantity):
            Self.netPNL(
                side: side,
                quantity: quantity,
                entryPrice: entryPrice,
                closingPrice: price,
                feeRate: feeRate,
            )
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
                sign: .whenNegative
            ) + ")"
        case .stopLoss:
            break
        }
        return (value: pnl, localized: maxChange)
    }
    
    private static func netPNL(
        side: PerpetualOrderSide,
        quantity: Decimal,
        entryPrice: Decimal,
        closingPrice: Decimal,
        feeRate: Decimal,
    ) -> Decimal {
        let grossPNL = (closingPrice - entryPrice) * quantity * (side == .long ? 1 : -1)
        let openingFee = quantity * entryPrice * feeRate
        let closingFee = quantity * closingPrice * feeRate
        return grossPNL - openingFee - closingFee
    }
    
}
