import Foundation

public enum NamedLargeNumberFormatter {
    
    public enum DisplayCurrency {
        case current
        case usd
    }
    
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.roundingMode = .floor
        formatter.positivePrefix = ""
        formatter.negativePrefix = ""
        formatter.locale = .current
        return formatter
    }()
    
    // https://en.wikipedia.org/wiki/Names_of_large_numbers
    private static let sextillion   = Decimal(sign: .plus, exponent: 21, significand: 1)
    private static let quintillion  = Decimal(sign: .plus, exponent: 18, significand: 1)
    private static let quadrillion  = Decimal(sign: .plus, exponent: 15, significand: 1)
    private static let trillion     = Decimal(sign: .plus, exponent: 12, significand: 1)
    private static let billion      = Decimal(sign: .plus, exponent: 9, significand: 1)
    private static let million      = Decimal(sign: .plus, exponent: 6, significand: 1)
    
    public static func string(number: Decimal, currency: DisplayCurrency?) -> String {
        if #available(iOS 18, *) {
            return switch currency {
            case .none:
                number.formatted(
                    Decimal.FormatStyle.number
                        .notation(.compactName)
                        .precision(.fractionLength(0...2))
                        .rounded(rule: .towardZero)
                )
            case .current:
                number.formatted(
                    Decimal.FormatStyle.Currency
                        .currency(code: Currency.current.code)
                        .presentation(.narrow)
                        .notation(.compactName)
                        .precision(.fractionLength(0...2))
                        .rounded(rule: .towardZero)
                )
            case .usd:
                number.formatted(
                    Decimal.FormatStyle.Currency
                        .currency(code: "USD")
                        .presentation(.narrow)
                        .notation(.compactName)
                        .precision(.fractionLength(0...2))
                        .rounded(rule: .towardZero)
                )
            }
        } else {
            let suffix: String
            let significand: Decimal
            switch number {
            case ...million:
                suffix = ""
                significand = number
            case million..<billion:
                suffix = "M"
                significand = number / million
            case billion..<trillion:
                suffix = "B"
                significand = number / billion
            case trillion..<quadrillion:
                suffix = "T"
                significand = number / trillion
            case quadrillion..<quintillion:
                suffix = "P"
                significand = number / quadrillion
            case quintillion..<sextillion:
                suffix = "E"
                significand = number / quintillion
            default:
                suffix = "Z"
                significand = number / sextillion
            }
            let string = formatter.string(decimal: significand) ?? "-"
            return switch currency {
            case .none:
                string + suffix
            case .current:
                Currency.current.symbol + string + suffix
            case .usd:
                "$" + string + suffix
            }
        }
    }
    
}
