import Foundation

public struct PerpetualPositionValue {
    
    public enum State {
        
        case gain
        case loss
        case neutral
        
        init(value: Decimal) {
            if value.isZero {
                self = .neutral
            } else if value > 0 {
                self = .gain
            } else {
                self = .loss
            }
        }
        
    }
    
    public let value: String
    public let change: String?
    public let state: State
    
    private init(value: String, change: String?, state: State) {
        self.value = value
        self.change = change
        self.state = state
    }
    
    static func open(entryValue: String, pnl: String, margin: String) -> PerpetualPositionValue {
        let decimalEntryValue = Decimal(string: entryValue, locale: .enUSPOSIX) ?? 0
        let decimalPnL = Decimal(string: pnl, locale: .enUSPOSIX) ?? 0
        let decimalMargin = Decimal(string: margin, locale: .enUSPOSIX) ?? 0
        
        let value = CurrencyFormatter.localizedString(
            from: (decimalEntryValue + decimalPnL) * Currency.current.decimalRate,
            format: .precision,
            sign: .never,
            symbol: .currencySymbol
        )
        
        let changeInFiatMoney = if decimalPnL == 0 {
            Currency.current.symbol + zeroWith2Fractions
        } else {
            CurrencyFormatter.localizedString(
                from: decimalPnL * Currency.current.decimalRate,
                format: .precision,
                sign: .always,
                symbol: .currencySymbol
            )
        }
        
        var change = changeInFiatMoney
        if decimalMargin != 0 {
            let changeInPercent = PercentageFormatter.string(
                from: decimalPnL / decimalMargin,
                format: .pretty,
                sign: .never,
                options: .keepOneFractionDigitForZero
            )
            change += "(" + changeInPercent + ")"
        }
        
        let state = State(value: decimalPnL)
        return PerpetualPositionValue(value: value, change: change, state: state)
    }
    
    static func closed(pnl: String) -> PerpetualPositionValue {
        let decimalPnL = Decimal(string: pnl, locale: .enUSPOSIX) ?? 0
        let value = CurrencyFormatter.localizedString(
            from: decimalPnL * Currency.current.decimalRate,
            format: .fiatMoney,
            sign: .always,
            symbol: .currencySymbol
        )
        let state = State(value: decimalPnL)
        return PerpetualPositionValue(value: value, change: nil, state: state)
    }
    
}
