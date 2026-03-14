import Foundation

public struct PerpetualPositionValue {
    
    public enum State {
        case gain
        case loss
        case neutral
    }
    
    public let value: String
    public let change: String
    public let state: State
    
    private init(value: String, change: String, state: State) {
        self.value = value
        self.change = change
        self.state = state
    }
    
    static func open(entryValue: String, pnl: String) -> PerpetualPositionValue {
        let decimalEntryValue = Decimal(string: entryValue, locale: .enUSPOSIX) ?? 0
        let decimalPnL = Decimal(string: pnl, locale: .enUSPOSIX) ?? 0
        let nowValue = decimalEntryValue + decimalPnL
        
        let value: String
        let changeInFiatMoney: String
        let changeInPercent: String
        if decimalEntryValue == 0 {
            changeInFiatMoney = Currency.current.symbol + zeroWith2Fractions
            changeInPercent = PercentageFormatter.string(
                from: 0,
                format: .pretty,
                sign: .never,
                options: .keepOneFractionDigitForZero,
            )
            value = changeInFiatMoney
        } else {
            changeInFiatMoney = CurrencyFormatter.localizedString(
                from: decimalPnL,
                format: .precision,
                sign: .always,
                symbol: .currencySymbol
            )
            changeInPercent = PercentageFormatter.string(
                from: nowValue / decimalEntryValue - 1,
                format: .pretty,
                sign: .never,
                options: .keepOneFractionDigitForZero,
            )
            value = CurrencyFormatter.localizedString(
                from: nowValue,
                format: .precision,
                sign: .never,
                symbol: .currencySymbol
            )
        }
        let change = changeInFiatMoney + "(" + changeInPercent + ")"
        let state: State = if decimalPnL.isZero {
            .neutral
        } else if decimalPnL > 0 {
            .gain
        } else {
            .loss
        }
        return PerpetualPositionValue(value: value, change: change, state: state)
    }
    
    static func closed(entryValue: String, pnl: String) -> PerpetualPositionValue {
        let decimalEntryValue = Decimal(string: entryValue, locale: .enUSPOSIX) ?? 0
        let decimalPnL = Decimal(string: pnl, locale: .enUSPOSIX) ?? 0
        let nowValue = decimalEntryValue + decimalPnL
        
        let value: String
        let change: String
        if decimalEntryValue == 0 {
            value = Currency.current.symbol + zeroWith2Fractions
            change = PercentageFormatter.string(
                from: 0,
                format: .pretty,
                sign: .never,
                options: .keepOneFractionDigitForZero,
            )
        } else {
            value = CurrencyFormatter.localizedString(
                from: decimalPnL,
                format: .precision,
                sign: .always,
                symbol: .currencySymbol
            )
            change = PercentageFormatter.string(
                from: nowValue / decimalEntryValue - 1,
                format: .pretty,
                sign: .always,
                options: .keepOneFractionDigitForZero,
            )
        }
        let state: State = if decimalPnL.isZero {
            .neutral
        } else if decimalPnL > 0 {
            .gain
        } else {
            .loss
        }
        return PerpetualPositionValue(value: value, change: change, state: state)
    }
    
}
