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
    
    public var decimal: Decimal {
        generic.decimal
    }
    
    public var doubleValue: Double {
        generic.doubleValue
    }
    
    public init?(string: String) {
        let whitespaceFiltered = string.filter { !$0.isWhitespace }
        guard let decimal = Self.formatter.number(from: whitespaceFiltered) as? Decimal else {
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
