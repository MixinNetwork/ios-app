import Foundation

public extension NumberFormatter {
    
    public static let percentage: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.roundingMode = .floor
        formatter.positivePrefix = ""
        formatter.negativePrefix = formatter.minusSign
        formatter.locale = .current
        return formatter
    }()
    
    static let usLocalizedDecimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .us
        return formatter
    }()
    
    static let enUSPOSIXLocalizedDecimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .enUSPOSIX
        return formatter
    }()
    
    static let decimal = NumberFormatter(numberStyle: .decimal)
    
    static let simplePercentage: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimum = 0.01
        formatter.maximum = 1
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.roundingMode = .floor
        formatter.locale = .current
        return formatter
    }()

    static let simpleFileSize: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.roundingMode = .halfUp
        return formatter
    }()
    
    static let userInputAmountSimulation: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.roundingMode = .floor
        formatter.maximumFractionDigits = 8
        formatter.usesGroupingSeparator = false
        return formatter
    }()
    
    convenience init(numberStyle: NumberFormatter.Style, maximumFractionDigits: Int? = nil, roundingMode: NumberFormatter.RoundingMode? = nil, locale: Locale? = nil) {
        self.init()
        self.numberStyle = numberStyle
        if let maximumFractionDigits = maximumFractionDigits {
            self.maximumFractionDigits = maximumFractionDigits
        }
        if let roundingMode = roundingMode {
            self.roundingMode = roundingMode
        }
        if let locale = locale {
            self.locale = locale
        }
    }

    func stringFormat(value: Float64) -> String {
        return string(from: NSNumber(value: value)) ?? "\(Int64(value))"
    }
    
    func string(decimal: Decimal) -> String? {
        string(from: decimal as NSDecimalNumber)
    }
    
}

public extension Int64 {

    func sizeRepresentation() -> String {
        let sizeInBytes = self
        if sizeInBytes < 1024 {
            return "\(sizeInBytes) Bytes"
        } else {
            let sizeInKB = Float64(sizeInBytes) / Float64(1024)
            if sizeInKB <= 1024 {
                return "\(NumberFormatter.simpleFileSize.stringFormat(value: sizeInKB)) KB"
            } else if sizeInKB > 1024 * 1024  {
                return "\(NumberFormatter.simpleFileSize.stringFormat(value: sizeInKB / Float64(1024 * 1024))) GB"
            } else {
                return "\(NumberFormatter.simpleFileSize.stringFormat(value: sizeInKB / Float64(1024))) MB"
            }
        }
    }

}

public extension Decimal {
    
    public static let wei = Decimal(sign: .plus, exponent: -18, significand: 1)
    public static let gwei = Decimal(sign: .plus, exponent: -9, significand: 1)
    public static let nanoton = Decimal(sign: .plus, exponent: -9, significand: 1)
    public static let satoshi = Decimal(sign: .plus, exponent: -8, significand: 1)
    
    public var numberOfSignificantFractionalDigits: Int {
        max(-exponent, 0)
    }
    
    public var reportingAssetLevel: String {
        switch self {
        case 0:
            "v0"
        case ..<100:
            "v1"
        case ..<1_000:
            "v100"
        case ..<10_000:
            "v1,000"
        case ..<100_000:
            "v10,000"
        case ..<1_000_000:
            "v100,000"
        case ..<10_000_000:
            "v1,000,000"
        default:
            "v10,000,000"
        }
    }
}

public extension NSDecimalNumberHandler {
    
    public static let extractIntegralPart = NSDecimalNumberHandler(
        roundingMode: .down,
        scale: 0,
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: false
    )
    
    public static let percentRoundingHandler = NSDecimalNumberHandler(
        roundingMode: .plain,
        scale: 2,
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: false
    )
    
}
