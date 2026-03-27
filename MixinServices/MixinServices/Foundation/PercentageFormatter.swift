import Foundation

public enum PercentageFormatter {
    
    public enum Format {
        case precision
        case pretty
    }
    
    public enum SignBehavior {
        case always
        case never
        case whenNegative
    }
    
    public struct Option: OptionSet {
        
        public static let keepOneFractionDigitForZero = Option(rawValue: 1 << 0)
        
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
    }
    
    private static let lock = NSLock()
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.roundingMode = .floor
        formatter.locale = .current
        return formatter
    }()
    
    public static func string(
        from decimal: Decimal,
        format: Format,
        sign: SignBehavior,
        options: Option = [],
    ) -> String {
        lock.lock()
        defer {
            lock.unlock()
        }
        switch format {
        case .precision:
            formatter.maximumFractionDigits = 8
        case .pretty:
            formatter.maximumFractionDigits = 2
        }
        switch sign {
        case .always:
            formatter.positivePrefix = formatter.plusSign
            formatter.negativePrefix = formatter.minusSign
        case .never:
            formatter.positivePrefix = ""
            formatter.negativePrefix = ""
        case .whenNegative:
            formatter.positivePrefix = ""
            formatter.negativePrefix = formatter.minusSign
        }
        if decimal == 0 && options.contains(.keepOneFractionDigitForZero) {
            formatter.minimumFractionDigits = 1
        } else {
            formatter.minimumFractionDigits = 0
        }
        if let string = formatter.string(decimal: decimal) {
            return string
        } else {
            let symbol = switch sign {
            case .always:
                decimal > 0 ? "+" : "-"
            case .never:
                ""
            case .whenNegative:
                decimal > 0 ? "" : "-"
            }
            return symbol + "\(decimal * 100)%"
        }
    }
    
}
