import Foundation

public struct CurrencyFormatter {
    
    public enum Format {
        case precision
        case pretty
        case fiatMoney
        case fiatMoneyPrice
        case fiatMoneyValue
    }
    
    public enum SignBehavior {
        case always
        case never
        case whenNegative
        case whenNotZero
    }
    
    public enum Symbol {
        case currencyCode
        case currencySymbol
        case custom(String)
    }
    
    private static let precisionFormatterLock = NSLock()
    private static let precisionFormatter: NumberFormatter = {
        let formatter = NumberFormatter(numberStyle: .decimal, maximumFractionDigits: 8, roundingMode: .down, locale: .current)
        formatter.locale = .current
        return formatter
    }()
    
    private static let prettyFormatterLock = NSLock()
    private static let prettyFormatter: NumberFormatter = {
        let formatter = NumberFormatter(numberStyle: .decimal, roundingMode: .down, locale: .current)
        formatter.locale = .current
        return formatter
    }()
    
    private static let fiatMoneyFormatterLock = NSLock()
    private static let fiatMoneyFormatter: NumberFormatter = {
        let formatter = NumberFormatter(numberStyle: .decimal, maximumFractionDigits: 2, roundingMode: .down, locale: .current)
        formatter.locale = .current
        return formatter
    }()
    
    private static let roundToIntegerBehavior = NSDecimalNumberHandler(
        roundingMode: .down,
        scale: 0,
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: false
    )
    
    public static func localizedString(from string: String?, locale: Locale = .us, format: Format, sign: SignBehavior, symbol: Symbol? = nil) -> String? {
        guard let string = string, let decimal = Decimal(string: string, locale: locale), decimal.isZero || decimal.isNormal else {
            return nil
        }
        return localizedString(from: decimal, format: format, sign: sign, symbol: symbol)
    }

    public static func localizedPrice(price: String, priceUsd: String) -> String {
        let value = CurrencyFormatter.localizedString(
            from: price.doubleValue * priceUsd.doubleValue * Currency.current.rate,
            format: .fiatMoney,
            sign: .never
        ) 
        return "≈ " + Currency.current.symbol + value
    }
    
    public static func localizedString(from number: Double, format: Format, sign: SignBehavior, symbol: Symbol? = nil) -> String {
        let decimal = Decimal(number)
        return localizedString(from: decimal, format: format, sign: sign, symbol: symbol)
    }
    
    public static func localizedString(from decimal: Decimal, format: Format, sign: SignBehavior, symbol: Symbol? = nil) -> String {
        let number = NSDecimalNumber(decimal: decimal)
        let isNumberZero = decimal.isZero
        var symbolPrefix: String = switch symbol {
        case .currencySymbol:
            Currency.current.symbol
        default:
            ""
        }
        
        var str: String
        
        switch format {
        case .precision:
            precisionFormatterLock.lock()
            precisionFormatter.setSignBehavior(sign, symbolPrefix: symbolPrefix, isNumberZero: isNumberZero)
            str = precisionFormatter.string(from: number) ?? "\(decimal)"
            precisionFormatterLock.unlock()
        case .pretty:
            prettyFormatterLock.lock()
            prettyFormatter.setSignBehavior(sign, symbolPrefix: symbolPrefix, isNumberZero: isNumberZero)
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
            str = prettyFormatter.string(from: number) ?? "\(decimal)"
            prettyFormatterLock.unlock()
        case .fiatMoney:
            fiatMoneyFormatterLock.lock()
            fiatMoneyFormatter.setSignBehavior(sign, symbolPrefix: symbolPrefix, isNumberZero: isNumberZero)
            str = fiatMoneyFormatter.string(from: number) ?? "\(decimal)"
            fiatMoneyFormatterLock.unlock()
        case .fiatMoneyPrice:
            if abs(decimal) < 1 {
                precisionFormatterLock.lock()
                precisionFormatter.setSignBehavior(sign, symbolPrefix: symbolPrefix, isNumberZero: isNumberZero)
                str = precisionFormatter.string(from: number) ?? "\(decimal)"
                precisionFormatterLock.unlock()
            } else {
                fiatMoneyFormatterLock.lock()
                fiatMoneyFormatter.setSignBehavior(sign, symbolPrefix: symbolPrefix, isNumberZero: isNumberZero)
                str = fiatMoneyFormatter.string(from: number) ?? "\(decimal)"
                fiatMoneyFormatterLock.unlock()
            }
        case .fiatMoneyValue:
            fiatMoneyFormatterLock.lock()
            let value: NSDecimalNumber
            if isNumberZero {
                value = 0
                fiatMoneyFormatter.minimumFractionDigits = 2
            } else if abs(decimal) < 0.01 {
                symbolPrefix.insert("<", at: symbolPrefix.startIndex)
                value = 0.01
            } else {
                value = number
            }
            fiatMoneyFormatter.setSignBehavior(sign, symbolPrefix: symbolPrefix, isNumberZero: isNumberZero)
            str = fiatMoneyFormatter.string(from: value) ?? "\(value)"
            if isNumberZero {
                fiatMoneyFormatter.minimumFractionDigits = 0
            }
            fiatMoneyFormatterLock.unlock()
        }
        
        switch symbol {
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
    
}

fileprivate extension NumberFormatter {
    
    func setSignBehavior(
        _ behavior: CurrencyFormatter.SignBehavior,
        symbolPrefix: String,
        isNumberZero: Bool
    ) {
        switch behavior {
        case .always:
            positivePrefix = plusSign
            negativePrefix = minusSign
        case .never:
            positivePrefix = ""
            negativePrefix = ""
        case .whenNegative:
            positivePrefix = ""
            negativePrefix = minusSign
        case .whenNotZero:
            if isNumberZero {
                positivePrefix = ""
                negativePrefix = ""
            } else {
                positivePrefix = plusSign
                negativePrefix = minusSign
            }
        }
        positivePrefix += symbolPrefix
        negativePrefix += symbolPrefix
    }
    
}
