import Foundation
import MixinServices

enum PerpetualChangeSimulation {
    
    static func profit(
        side: PerpetualOrderSide,
        margin: Decimal,
        leverageMultiplier: Decimal,
        priceChangePercent: Decimal,
    ) -> String {
        let priceChange = PercentageFormatter.string(
            from: priceChangePercent,
            format: .pretty,
            sign: .never
        )
        let exposure = priceChangePercent * leverageMultiplier
        let profit = PercentageFormatter.string(
            from: exposure,
            format: .pretty,
            sign: .never
        )
        
        if margin > 0 {
            let profitValue = CurrencyFormatter.localizedString(
                from: margin * exposure,
                format: .fiatMoneyPretty,
                sign: .always,
                symbol: .dollarSign
            )
            return switch side {
            case .long:
                R.string.localizable.price_rise_profit_value(priceChange, profit, profitValue)
            case .short:
                R.string.localizable.price_fall_profit_value(priceChange, profit, profitValue)
            }
        } else {
            return switch side {
            case .long:
                R.string.localizable.price_rise_profit(priceChange, profit)
            case .short:
                R.string.localizable.price_fall_profit(priceChange, profit)
            }
        }
    }
    
    static func liquidation(
        side: PerpetualOrderSide,
        margin: Decimal,
        leverageMultiplier: Decimal,
    ) -> String {
        let percentage = PercentageFormatter.string(
            from: 1 / leverageMultiplier,
            format: .pretty,
            sign: .never
        )
        if margin == 0 {
            return switch side {
            case .long:
                R.string.localizable.price_fall_loss_all(percentage)
            case .short:
                R.string.localizable.price_rise_loss_all(percentage)
            }
        } else {
            let marginValue = CurrencyFormatter.localizedString(
                from: -margin,
                format: .fiatMoneyPretty,
                sign: .always,
                symbol: .dollarSign
            )
            return switch side {
            case .long:
                R.string.localizable.price_fall_loss(percentage, marginValue)
            case .short:
                R.string.localizable.price_rise_loss(percentage, marginValue)
            }
        }
    }
    
    static func liquidation(
        side: PerpetualOrderSide,
        margin: Decimal,
        entryPrice: Decimal,
        liquidationPrice: Decimal,
    ) -> String {
        let percentage = PercentageFormatter.string(
            from: abs(entryPrice - liquidationPrice) / entryPrice,
            format: .pretty,
            sign: .never
        )
        if margin == 0 {
            return switch side {
            case .long:
                R.string.localizable.price_fall_loss_all(percentage)
            case .short:
                R.string.localizable.price_rise_loss_all(percentage)
            }
        } else {
            let marginValue = CurrencyFormatter.localizedString(
                from: -margin,
                format: .fiatMoneyPretty,
                sign: .always,
                symbol: .dollarSign
            )
            return switch side {
            case .long:
                R.string.localizable.price_fall_loss(percentage, marginValue)
            case .short:
                R.string.localizable.price_rise_loss(percentage, marginValue)
            }
        }
    }
    
}
