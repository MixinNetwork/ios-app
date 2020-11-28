import Foundation
import BigNumber

// This is the end solution of handling decimal values, basically for token amount
// NSDecimal or NSDecimalNumber loses its precision when mantissa has more than 38 digits
public struct DecimalNumber {
    
    public typealias NumberOfDigits = (integer: Int, fraction: Int)
    
    private var number: BDouble
    
    public var isZero: Bool {
        number.isZero()
    }
    
    // This is the approximation in Double, precision maybe losing
    public var doubleValue: Double {
        Double(stringValue) ?? 0
    }
    
    // This is the generalized string, using english numerics and "." for decimal separator, no grouping separator
    public var stringValue: String {
        var value = number.decimalExpansion(precisionAfterDecimalPoint: maxFractionDigitsOfTokenAmount, rounded: false)
        value = Self.trimPaddingZeroInFraction(value)
        return value
    }
    
    // DecimalNumber holds infinite digits of mantissa
    // Returns nil if percision will be losing during conversion
    public var nsDecimalNumber: NSDecimalNumber? {
        if Self.canConvertToNSDecimalNumberWithoutLosingPrecision(number) {
            return NSDecimalNumber(string: stringValue, locale: Locale.us)
        } else {
            return nil
        }
    }
    
    public var numberOfDigits: NumberOfDigits {
        Self.numberOfDigits(stringValue)
    }
    
    public init?(string: String) {
        if let number = BDouble(string) {
            self.init(number: number)
        } else {
            return nil
        }
    }
    
    public init?(localizedString: String) {
        let whitespaceFiltered = localizedString.filter { !$0.isWhitespace }
        let maybeDecimal = Self.preferredLocaleFormatter.number(from: whitespaceFiltered)
            ?? Self.currentLocaleFormatter.number(from: whitespaceFiltered)
        if let decimal = maybeDecimal as? Decimal, let number = Self.bDouble(from: decimal) {
            self.init(number: number)
        } else {
            var string = whitespaceFiltered.applyingTransform(.toLatin, reverse: false) ?? ""
            if let separator = Locale.current.groupingSeparator {
                string = string.replacingOccurrences(of: separator, with: "")
            }
            if let separator = Locale.current.decimalSeparator {
                string = string.replacingOccurrences(of: separator, with: Self.decimalSeparator)
            }
            if !string.isEmpty, let number = BDouble(string) {
                self.init(number: number)
            } else {
                return nil
            }
        }
    }
    
    private init(number: BDouble) {
        var theNumber = number
        theNumber.precision = maxFractionDigitsOfTokenAmount
        self.number = theNumber
    }
    
    public static func isValidNumber(localizedString: String) -> Bool {
        if let _ = Self(localizedString: localizedString) {
            return true
        } else {
            return false
        }
    }
    
    public func numberByRoundingDownFraction(with numberOfDigits: Int) -> DecimalNumber {
        let currentNumberOfFractionDigits = self.numberOfDigits.fraction
        guard currentNumberOfFractionDigits > numberOfDigits else {
            return self
        }
        var string = stringValue
        let endIndex = string.index(string.endIndex, offsetBy: currentNumberOfFractionDigits - numberOfDigits)
        string = String(string[string.startIndex..<endIndex])
        return DecimalNumber(string: string)!
    }
    
}

extension DecimalNumber: Equatable {
    
    public static func ==(lhs: DecimalNumber, rhs: DecimalNumber) -> Bool {
        lhs.number == rhs.number
    }
    
}

extension DecimalNumber: Comparable {
    
    public static func < (lhs: DecimalNumber, rhs: DecimalNumber) -> Bool {
        lhs.number < rhs.number
    }
    
    public static func <= (lhs: DecimalNumber, rhs: DecimalNumber) -> Bool {
        lhs.number <= rhs.number
    }
    
    public static func >= (lhs: DecimalNumber, rhs: DecimalNumber) -> Bool {
        lhs.number >= rhs.number
    }
    
    public static func > (lhs: DecimalNumber, rhs: DecimalNumber) -> Bool {
        lhs.number > rhs.number
    }
    
}

extension DecimalNumber : ExpressibleByFloatLiteral {
    
    public init(floatLiteral value: Double) {
        self.init(value)
    }
    
}

extension DecimalNumber : ExpressibleByIntegerLiteral {
    
    public init(integerLiteral value: Int) {
        self.init(value)
    }
    
}

extension DecimalNumber : SignedNumeric {
    
    public var magnitude: DecimalNumber {
        self
    }
    
    public init?<T : BinaryInteger>(exactly source: T) {
        if let number = BDouble(exactly: source) {
            self.init(number: number)
        } else {
            return nil
        }
    }
    
    public static func +=(lhs: inout DecimalNumber, rhs: DecimalNumber) {
        lhs.number += rhs.number
    }
    
    public static func -=(lhs: inout DecimalNumber, rhs: DecimalNumber) {
        lhs.number -= rhs.number
    }
    
    public static func *=(lhs: inout DecimalNumber, rhs: DecimalNumber) {
        lhs.number *= rhs.number
    }
    
    public static func /=(lhs: inout DecimalNumber, rhs: DecimalNumber) {
        lhs.number = lhs.number / rhs.number
    }
    
    public static func +(lhs: DecimalNumber, rhs: DecimalNumber) -> DecimalNumber {
        DecimalNumber(number: lhs.number + rhs.number)
    }
    
    public static func -(lhs: DecimalNumber, rhs: DecimalNumber) -> DecimalNumber {
        DecimalNumber(number: lhs.number - rhs.number)
    }
    
    public static func *(lhs: DecimalNumber, rhs: DecimalNumber) -> DecimalNumber {
        DecimalNumber(number: lhs.number * rhs.number)
    }
    
    public static func /(lhs: DecimalNumber, rhs: DecimalNumber) -> DecimalNumber {
        DecimalNumber(number: lhs.number / rhs.number)
    }
    
    public mutating func negate() {
        number.negate()
    }
    
}

extension DecimalNumber {
    
    public init(_ value: UInt8) {
        self.init(UInt64(value))
    }
    
    public init(_ value: Int8) {
        self.init(Int64(value))
    }
    
    public init(_ value: UInt16) {
        self.init(UInt64(value))
    }
    
    public init(_ value: Int16) {
        self.init(Int64(value))
    }
    
    public init(_ value: UInt32) {
        self.init(UInt64(value))
    }
    
    public init(_ value: Int32) {
        self.init(Int64(value))
    }
    
    public init(_ value: UInt64) {
        let number = BDouble(BInt(value))
        self.init(number: number)
    }
    
    public init(_ value: Int64) {
        self.init(value.magnitude)
    }
    
    public init(_ value: UInt) {
        self.init(UInt64(value))
    }
    
    public init(_ value: Int) {
        self.init(Int64(value))
    }
    
    public init(_ value: Double) {
        let number = BDouble(value)
        self.init(number: number)
    }
    
}

extension DecimalNumber: Decodable {
    
    enum DecodingError: Error {
        case unsupportedValue
        case abnormalDecimal
        case abnormalNumberString
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let decimal = try? container.decode(Decimal.self) {
            if decimal.isZero || decimal.isNormal, let string = Self.generalFormatter.string(from: decimal as NSDecimalNumber), let number = BDouble(string) {
                self.init(number: number)
            } else {
                throw DecodingError.abnormalDecimal
            }
        } else if let string = try? container.decode(String.self) {
            if let number = BDouble(string) {
                self.init(number: number)
            } else {
                throw DecodingError.abnormalNumberString
            }
        } else {
            throw DecodingError.unsupportedValue
        }
    }
    
}

extension DecimalNumber {
    
    private static let decimalSeparatorCharacter: Character = "."
    private static let decimalSeparator = String(decimalSeparatorCharacter)
    private static let signAndExponentialCharacterSet = CharacterSet(charactersIn: "-0.")
    private static let maxNumberOfMantissaSupportedByNSDecimal = 38
    private static let currentLocaleFormatter = formatter(locale: .current)
    private static let preferredLocaleFormatter = formatter(locale: .preferred)
    
    private static let generalFormatter: NumberFormatter = {
        let formatter = Self.formatter(locale: .us)
        formatter.decimalSeparator = decimalSeparator
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 8
        return formatter
    }()
    
    private static func formatter(locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.generatesDecimalNumbers = true
        return formatter
    }
    
    // Returns nil if the decimal is nan, or it holds more mantissa digits than the precision limit
    private static func bDouble(from decimal: Decimal) -> BDouble? {
        guard decimal.isZero || decimal.isNormal else {
            return nil
        }
        guard let string = Self.generalFormatter.string(from: decimal as NSDecimalNumber) else {
            return nil
        }
        if let number = BDouble(string), Self.canConvertToNSDecimalNumberWithoutLosingPrecision(number) {
            return number
        } else {
            return nil
        }
    }
    
    private static func numberOfDigits(_ string: String) -> NumberOfDigits {
        if let separatorIndex = string.lastIndex(of: decimalSeparatorCharacter) {
            let fraction = string.distance(from: separatorIndex, to: string.endIndex) - 1
            let integer = string.count - fraction - 1
            return (integer, fraction)
        } else {
            return (string.count, 0)
        }
    }
    
    private static func trimPaddingZeroInFraction(_ string: String) -> String {
        var output = string
        guard output.contains(Self.decimalSeparatorCharacter) else {
            return output
        }
        while output.last == "0" {
            output.removeLast()
        }
        if output.last == Self.decimalSeparatorCharacter {
            output.removeLast()
        }
        return output
    }
    
    private static func canConvertToNSDecimalNumberWithoutLosingPrecision(_ number: BDouble) -> Bool {
        var mantissa = number.decimalExpansion(precisionAfterDecimalPoint: maxFractionDigitsOfTokenAmount, rounded: false)
        mantissa = trimPaddingZeroInFraction(mantissa)
        if mantissa.hasMinusPrefix {
            mantissa.removeFirst()
        }
        if mantissa.hasPrefix("0.") {
            mantissa.removeFirst(2)
            while mantissa.first == "0" {
                mantissa.removeFirst()
            }
        }
        var mantissaCount = mantissa.count
        if mantissa.contains(decimalSeparatorCharacter) {
            mantissaCount -= 1
        }
        return mantissaCount <= maxNumberOfMantissaSupportedByNSDecimal
    }
    
}
