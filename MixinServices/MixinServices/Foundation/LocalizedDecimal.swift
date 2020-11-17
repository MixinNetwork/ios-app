import Foundation

public class LocalizedDecimal {
    
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.generatesDecimalNumbers = true
        return formatter
    }()
    
    public let generic: GenericDecimal
    
    public var doubleValue: Double {
        generic.doubleValue
    }
    
    public required init?(string: String) {
        let whitespaceFiltered = string.filter { !$0.isWhitespace }
        guard let decimal = Self.formatter.number(from: whitespaceFiltered) as? Decimal else {
            return nil
        }
        guard decimal.isNormal else {
            return nil
        }
        self.generic = GenericDecimal(decimal: decimal)
    }
    
    public static func isValidDecimal(_ string: String) -> Bool {
        if let _ = Self(string: string) {
            return true
        } else {
            return false
        }
    }
    
}
