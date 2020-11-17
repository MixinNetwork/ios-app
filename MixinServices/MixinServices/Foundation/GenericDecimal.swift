import Foundation

public class GenericDecimal {
    
    public static let decimalSeparator = "."
    
    private static let legalCharacters: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "-", "."]
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.decimalSeparator = decimalSeparator
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
        guard !string.isEmpty && Set(string).isSubset(of: Self.legalCharacters) else {
            // Number formatter recognize any numeral systems as long as it respects number format of the locale
            // e.g. arabic number "۱۰.۱" is recognized by the formatter as 10.1
            // Drop any number characters other than english ones
            return nil
        }
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
