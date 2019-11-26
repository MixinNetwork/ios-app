import Foundation

struct CurrencyFormatter {
    
    static let precisionFormatter: NumberFormatter = {
        let formatter = NumberFormatter(numberStyle: .decimal, maximumFractionDigits: 8, roundingMode: .down, locale: .current)
        formatter.locale = .current
        return formatter
    }()
    static let prettyFormatter: NumberFormatter = {
        let formatter = NumberFormatter(numberStyle: .decimal, roundingMode: .down, locale: .current)
        formatter.locale = .current
        return formatter
    }()
    static let fiatMoneyFormatter: NumberFormatter = {
        let formatter = NumberFormatter(numberStyle: .decimal, maximumFractionDigits: 2, roundingMode: .down, locale: .current)
        formatter.locale = .current
        return formatter
    }()
    static let roundToIntegerBehavior = NSDecimalNumberHandler(roundingMode: .down, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
    
    enum Format {
        case precision
        case pretty
        case fiatMoney
        case fiatMoneyPrice
    }
    
    enum SignBehavior {
        case always
        case never
        case whenNegative
    }
    
    enum Symbol {
        case btc
        case currentCurrency
        case custom(String)
    }
    
    static func localizedString(from string: String?, locale: Locale = .us, format: Format, sign: SignBehavior, symbol: Symbol? = nil) -> String? {
        guard let string = string, let decimal = Decimal(string: string, locale: locale), decimal.isZero || decimal.isNormal else {
            return nil
        }
        return formattedString(from: decimal, format: format, sign: sign, symbol: symbol)
    }
    
    static func localizedString(from number: Double, format: Format, sign: SignBehavior, symbol: Symbol? = nil) -> String? {
        let decimal = Decimal(number)
        return formattedString(from: decimal, format: format, sign: sign, symbol: symbol)
    }
    
    private static func formattedString(from decimal: Decimal, format: Format, sign: SignBehavior, symbol: Symbol? = nil) -> String? {
        let number = NSDecimalNumber(decimal: decimal)
        var str: String
        
        switch format {
        case .precision:
            setSignBehavior(sign, for: precisionFormatter)
            str = precisionFormatter.string(from: number) ?? ""
        case .pretty:
            setSignBehavior(sign, for: prettyFormatter)
            let numberOfFractionalDigits = max(-decimal.exponent, 0)
            let integralPart = number.rounding(accordingToBehavior: roundToIntegerBehavior).doubleValue
            if integralPart == 0 {
                prettyFormatter.maximumFractionDigits = 8
            } else if numberOfFractionalDigits > 0 {
                let numberOfIntegralDigits = Int(floor(log10(abs(integralPart)))) + 1
                prettyFormatter.maximumFractionDigits = max(0, 8 - numberOfIntegralDigits)
            } else {
                prettyFormatter.maximumFractionDigits = 0
            }
            str = prettyFormatter.string(from: number) ?? ""
        case .fiatMoney:
            setSignBehavior(sign, for: fiatMoneyFormatter)
            str = fiatMoneyFormatter.string(from: number) ?? ""
        case .fiatMoneyPrice:
            if decimal.isLess(than: 1) {
                setSignBehavior(sign, for: precisionFormatter)
                str = precisionFormatter.string(from: number) ?? ""
            } else {
                setSignBehavior(sign, for: fiatMoneyFormatter)
                str = fiatMoneyFormatter.string(from: number) ?? ""
            }
        }
        
        if let symbol = symbol {
            switch symbol {
            case .btc:
                str += " BTC"
            case .currentCurrency:
                str += " " + Currency.current.code
            case .custom(let symbol):
                str += " " + symbol
            }
        }
        
        return str
    }
    
    private static func setSignBehavior(_ sign: SignBehavior, for formatter: NumberFormatter) {
        switch sign {
        case .always:
            formatter.positivePrefix = formatter.plusSign
            formatter.negativePrefix = formatter.minusSign
        case .never:
            formatter.positivePrefix = ""
            formatter.negativePrefix = ""
        case .whenNegative:
            formatter.positivePrefix = ""
            formatter.negativePrefix = formatter.minusSign
        }
    }
    
}

extension Locale {
    static let us = Locale(identifier: "US")
}
