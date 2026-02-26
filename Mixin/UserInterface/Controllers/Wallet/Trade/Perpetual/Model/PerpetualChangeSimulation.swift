import Foundation
import MixinServices

enum PerpetualChangeSimulation {
    
    static func profit(
        side: PerpetualOrderSide,
        margin: Decimal,
        leverageMultiplier: Decimal,
        priceChangePercent: Decimal,
    ) -> String {
        let priceChange = NumberFormatter.percentage.string(
            from: priceChangePercent as NSDecimalNumber
        ) ?? "\(priceChangePercent * 100)%"
        
        let exposure = priceChangePercent * leverageMultiplier
        let profit = NumberFormatter.percentage.string(
            from: exposure as NSDecimalNumber
        ) ?? "\(exposure * 100)%"
        
        if margin > 0 {
            let profitValue = CurrencyFormatter.localizedString(
                from: margin * exposure * Currency.current.decimalRate,
                format: .precision,
                sign: .never,
                symbol: .currencySymbol
            )
            return switch side {
            case .long:
                "价格上涨 \(priceChange) → 盈利 \(profit)（+\(profitValue)）"
            case .short:
                "价格下跌 \(priceChange) → 盈利 \(profit)（+\(profitValue)）"
            }
        } else {
            return switch side {
            case .long:
                "价格上涨 \(priceChange) → 盈利 \(profit)"
            case .short:
                "价格下跌 \(priceChange) → 盈利 \(profit)"
            }
        }
    }
    
    static func liquidationPrice(
        side: PerpetualOrderSide,
        entryPrice: Decimal,
        leverageMultiplier: Decimal,
    ) -> String {
        let liquidationChangePercentage = 1 / leverageMultiplier
        let price = switch side {
        case .long:
            entryPrice * (1 - liquidationChangePercentage)
        case .short:
            entryPrice * (1 + liquidationChangePercentage)
        }
        return CurrencyFormatter.localizedString(
            from: price * Currency.current.decimalRate,
            format: .precision,
            sign: .never,
            symbol: .currencySymbol
        )
    }
    
    static func liquidation(
        side: PerpetualOrderSide,
        margin: Decimal,
        leverageMultiplier: Decimal,
    ) -> String {
        let liquidationChangePercentage = 1 / leverageMultiplier
        let percentage = NumberFormatter.percentage.string(
            from: liquidationChangePercentage as NSDecimalNumber
        ) ?? "\(liquidationChangePercentage * 100)%"
        let marginValue = CurrencyFormatter.localizedString(
            from: margin * Currency.current.decimalRate,
            format: .precision,
            sign: .never,
            symbol: .currencySymbol
        )
        return switch side {
        case .long:
            "价格下跌 \(percentage) → 亏损 -\(marginValue)"
        case .short:
            "价格上涨 \(percentage) → 亏损 -\(marginValue)"
        }
    }
    
}
