import Foundation

public enum CurrencyFormatter {
    
    public enum Format {
        case precision
        case pretty
        case fiatMoney
        case fiatMoneyPrice
    }
    
    public enum SignBehavior {
        case always
        case never
        case whenNegative
    }
    
    public enum Symbol {
        case btc
        case currentCurrency
        case custom(String)
    }
    
    private static let precisionFormatter = decimalFormatter(maximumFractionDigits: 8)
    private static let prettyFormatter = decimalFormatter(maximumFractionDigits: nil)
    private static let fiatMoneyFormatter = decimalFormatter(maximumFractionDigits: 2)
    
    private static let prettyRounding = NSDecimalNumberHandler(roundingMode: .down,
                                                               scale: 0,
                                                               raiseOnExactness: false,
                                                               raiseOnOverflow: false,
                                                               raiseOnUnderflow: false,
                                                               raiseOnDivideByZero: false)
    
    public static func localizedFiatMoneyEstimation(asset: AssetItem, tokenAmount: Decimal) -> String {
        let value = tokenAmount * asset.decimalUSDPrice * Currency.current.rate
        let string = CurrencyFormatter.localizedString(from: value, format: .fiatMoney, sign: .never)
        return "≈ " + Currency.current.symbol + string
    }
    
    public static func localizedString(from decimal: Decimal, format: Format, sign: SignBehavior, symbol: Symbol? = nil) -> String {
        let number = NSDecimalNumber(decimal: decimal)
        var str: String
        
        switch format {
        case .precision:
            setSignBehavior(sign, for: precisionFormatter)
            str = precisionFormatter.string(from: number) ?? ""
        case .pretty:
            setSignBehavior(sign, for: prettyFormatter)
            let numberOfFractionalDigits = max(-decimal.exponent, 0)
            let integralPart = number.rounding(accordingToBehavior: prettyRounding).doubleValue
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
    
}

extension CurrencyFormatter {
    
    private static func decimalFormatter(maximumFractionDigits: Int?) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if let maximumFractionDigits = maximumFractionDigits {
            formatter.maximumFractionDigits = maximumFractionDigits
        }
        formatter.roundingMode = .down
        formatter.locale = .current
        return formatter
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
