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
        formatter.maximumFractionDigits = 8
        return formatter
    }()
    
    public let decimal: Decimal
    
    // Since we have a normal decimal, the formatter should work
    // See https://lists.apple.com/archives/cocoa-dev/2002/Dec/msg00370.html
    public private(set) lazy var string = Self.formatter.string(from: decimal as NSDecimalNumber)!
    
    public var intValue: Int {
        (decimal as NSDecimalNumber).intValue
    }
    
    public var int64Value: Int64 {
        (decimal as NSDecimalNumber).int64Value
    }
    
    public var doubleValue: Double {
        decimal.doubleValue
    }
    
    public init?(decimal: Decimal) {
        guard decimal.isNormal || decimal.isZero else {
            return nil
        }
        self.decimal = decimal
    }
    
    public convenience init?(string: String) {
        guard !string.isEmpty && Set(string).isSubset(of: Self.legalCharacters) else {
            // Number formatter recognize any numeral systems as long as it respects number format of the locale
            // e.g. arabic number "۱۰.۱" is recognized by the formatter as 10.1
            // Drop any number characters other than english ones
            return nil
        }
        guard let decimal = Self.formatter.number(from: string) as? Decimal else {
            return nil
        }
        self.init(decimal: decimal)
    }
    
    public static func isValidDecimal(_ string: String) -> Bool {
        if let _ = GenericDecimal(string: string) {
            return true
        } else {
            return false
        }
    }
    
}
