import Foundation

public struct CurrencyFormatter {
    
    public enum Format {
        case precision
        case pretty
        case fiatMoney
        case fiatMoneyPrice
        case networkFee
    }
    
    public enum SignBehavior {
        case always
        case never
        case whenNegative
    }
    
    public enum Symbol {
        case btc
        case currencyCode
        case currencySymbol
        case custom(String)
    }
    
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
    
    static let networkFeeFormatter: NumberFormatter = {
        let formatter = NumberFormatter(numberStyle: .decimal, maximumFractionDigits: 4, roundingMode: .up, locale: .current)
        formatter.locale = .current
        return formatter
    }()
    
    static let roundToIntegerBehavior = NSDecimalNumberHandler(roundingMode: .down, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
    
    public static func localizedString(from string: String?, locale: Locale = .us, format: Format, sign: SignBehavior, symbol: Symbol? = nil) -> String? {
        guard let string = string, let decimal = Decimal(string: string, locale: locale), decimal.isZero || decimal.isNormal else {
            return nil
        }
        return localizedString(from: decimal, format: format, sign: sign, symbol: symbol)
    }

    public static func localizedPrice(price: String, priceUsd: String) -> String {
        guard let value = CurrencyFormatter.localizedString(from: price.doubleValue * priceUsd.doubleValue * Currency.current.rate, format: .fiatMoney, sign: .never) else {
            return price
        }
        
        return "≈ " + Currency.current.symbol + value
    }
    
    public static func estimatedFiatMoneyValue(amount: Decimal) -> String {
        "≈ " + Currency.current.symbol + CurrencyFormatter.localizedString(from: amount, format: .fiatMoney, sign: .never)
    }
    
    public static func localizedString(from number: Double, format: Format, sign: SignBehavior, symbol: Symbol? = nil) -> String? {
        let decimal = Decimal(number)
        return localizedString(from: decimal, format: format, sign: sign, symbol: symbol)
    }
    
    public static func localizedString(from decimal: Decimal, format: Format, sign: SignBehavior, symbol: Symbol? = nil) -> String {
        let number = NSDecimalNumber(decimal: decimal)
        let symbolPrefix: String? = switch symbol {
        case .currencySymbol:
            Currency.current.symbol
        default:
            nil
        }
        
        var str: String
        
        switch format {
        case .precision:
            setSignBehavior(sign, symbolPrefix: symbolPrefix, for: precisionFormatter)
            str = precisionFormatter.string(from: number) ?? ""
        case .pretty:
            setSignBehavior(sign, symbolPrefix: symbolPrefix, for: prettyFormatter)
            let numberOfFractionalDigits = decimal.numberOfSignificantFractionalDigits
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
            setSignBehavior(sign, symbolPrefix: symbolPrefix, for: fiatMoneyFormatter)
            str = fiatMoneyFormatter.string(from: number) ?? ""
        case .fiatMoneyPrice:
            if abs(decimal) < 1 {
                setSignBehavior(sign, symbolPrefix: symbolPrefix, for: precisionFormatter)
                str = precisionFormatter.string(from: number) ?? ""
            } else {
                setSignBehavior(sign, symbolPrefix: symbolPrefix, for: fiatMoneyFormatter)
                str = fiatMoneyFormatter.string(from: number) ?? ""
            }
        case .networkFee:
            setSignBehavior(sign, symbolPrefix: symbolPrefix, for: networkFeeFormatter)
            str = networkFeeFormatter.string(from: number) ?? ""
        }
        
        switch symbol {
        case .btc:
            str += " BTC"
        case .currencyCode:
            str += " " + Currency.current.code
        case .currencySymbol:
            // Inserted with `setSignBehavior`
            break
        case .custom(let symbol):
            str += " " + symbol
        case nil:
            break
        }
        
        return str
    }
    
    private static func setSignBehavior(
        _ sign: SignBehavior,
        symbolPrefix: String?,
        for formatter: NumberFormatter
    ) {
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
        if let prefix = symbolPrefix {
            formatter.positivePrefix = formatter.positivePrefix + prefix
            formatter.negativePrefix = formatter.negativePrefix + prefix
        }
    }
    
}
