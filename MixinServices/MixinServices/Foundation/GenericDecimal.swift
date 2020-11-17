import Foundation

public class GenericDecimal {
    
    public static let decimalSeparator = Locale.us.decimalSeparator ?? "."
    
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .us
        formatter.generatesDecimalNumbers = true
        formatter.usesGroupingSeparator = false
        return formatter
    }()
    
    public let decimal: Decimal
    
    // Since we have a normal decimal, the formatter should work
    // See https://lists.apple.com/archives/cocoa-dev/2002/Dec/msg00370.html
    public private(set) lazy var string = Self.formatter.string(from: decimal as NSNumber)!
    
    public var doubleValue: Double {
        (decimal as NSDecimalNumber).doubleValue
    }
    
    public init(decimal: Decimal) {
        self.decimal = decimal
    }
    
    public required init?(string: String) {
        guard let decimal = Self.formatter.number(from: string) as? Decimal else {
            return nil
        }
        guard decimal.isNormal else {
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
