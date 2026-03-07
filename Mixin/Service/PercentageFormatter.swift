import Foundation

enum PercentageFormatter {
    
    enum SignBehavior {
        case always
        case never
        case whenNegative
    }
    
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.roundingMode = .floor
        formatter.locale = .current
        return formatter
    }()
    
    static func string(from decimal: Decimal, sign: SignBehavior) -> String {
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
            return symbol + "\(decimal)%"
        }
    }
    
}
