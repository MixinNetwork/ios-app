import Foundation

public struct GenericDecimal {
    
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .us
        formatter.generatesDecimalNumbers = true
        formatter.usesGroupingSeparator = false
        return formatter
    }()
    
    public let decimal: Decimal
    
    public var doubleValue: Double {
        (decimal as NSDecimalNumber).doubleValue
    }
    
    public init(decimal: Decimal) {
        self.decimal = decimal
    }
    
    public init?(string: String) {
        guard let decimal = Self.formatter.number(from: string) as? Decimal else {
            return nil
        }
        self.decimal = decimal
    }
    
    public static func isValidDecimal(_ string: String) -> Bool {
        if let _ = Self(string: string) {
            return true
        } else {
            return false
        }
    }
    
}
