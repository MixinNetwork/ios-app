import Foundation

public class LocalizedDecimal {
    
    public let generic: GenericDecimal
    
    public var decimal: Decimal {
        generic.decimal
    }
    
    public var doubleValue: Double {
        generic.doubleValue
    }
    
    public init?(string: String) {
        let whitespaceFiltered = string.filter { !$0.isWhitespace }
        let maybeDecimal = (Self.preferredLocaleFormatter.number(from: whitespaceFiltered) as? Decimal)
            ?? (Self.currentLocaleFormatter.number(from: whitespaceFiltered) as? Decimal)
        guard let decimal = maybeDecimal else {
            return nil
        }
        guard let generic = GenericDecimal(decimal: decimal) else {
            return nil
        }
        self.generic = generic
    }
    
    public static func isValidDecimal(_ string: String) -> Bool {
        if let _ = LocalizedDecimal(string: string) {
            return true
        } else {
            return false
        }
    }
    
}

extension LocalizedDecimal {
    
    private static let currentLocaleFormatter = formatter(locale: .current)
    private static let preferredLocaleFormatter = formatter(locale: .preferred)
    
    private static func formatter(locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.generatesDecimalNumbers = true
        return formatter
    }
    
}
