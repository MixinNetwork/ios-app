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
    
    public let decimalValue: Decimal
    public let value: String
    public let changeValue: String?
    public let change: String?
    public let state: State
    
    private init(
        decimalValue: Decimal,
        value: String,
        changeValue: String?,
        change: String?,
        state: State,
    ) {
        self.decimalValue = decimalValue
        self.value = value
        self.changeValue = changeValue
        self.change = change
        self.state = state
    }
    
    static func open(margin: String, pnl: String) -> PerpetualPositionValue {
        let decimalMargin = Decimal(string: margin, locale: .enUSPOSIX) ?? 0
        let decimalPnL = Decimal(string: pnl, locale: .enUSPOSIX) ?? 0
        
        let decimalValue = decimalMargin
        let value = CurrencyFormatter.localizedString(
            from: decimalValue,
            format: .fiatMoneyPretty,
            sign: .never,
            symbol: .dollarSign
        )
        
        let changeValue = if decimalPnL == 0 {
            Currency.current.symbol + zeroWith2Fractions
        } else {
            CurrencyFormatter.localizedString(
                from: decimalPnL,
                format: .fiatMoneyPretty,
                sign: .always,
                symbol: .dollarSign
            )
        }
        
        var change = changeValue
        if decimalMargin != 0 {
            let changeInPercent = PercentageFormatter.string(
                from: decimalPnL / decimalMargin,
                format: .pretty,
                sign: .never,
                options: .keepOneFractionDigitForZero
            )
            change += " (" + changeInPercent + ")"
        }
        
        let state = State(value: decimalPnL)
        return PerpetualPositionValue(
            decimalValue: decimalValue,
            value: value,
            changeValue: changeValue,
            change: change,
            state: state
        )
    }
    
    static func closed(pnl: String) -> PerpetualPositionValue {
        let decimalValue = Decimal(string: pnl, locale: .enUSPOSIX) ?? 0
        let value = CurrencyFormatter.localizedString(
            from: decimalValue,
            format: .fiatMoneyPretty,
            sign: .always,
            symbol: .dollarSign
        )
        let state = State(value: decimalValue)
        return PerpetualPositionValue(
            decimalValue: decimalValue,
            value: value,
            changeValue: nil,
            change: nil,
            state: state
        )
    }
    
}
