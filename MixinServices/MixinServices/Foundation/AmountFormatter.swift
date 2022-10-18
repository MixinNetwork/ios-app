import Foundation

public enum AmountFormatter {
    
    enum Error: Swift.Error {
        case invalidAmount(String)
    }
    
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .enUSPOSIX
        formatter.maximumFractionDigits = 8
        return formatter
    }()
    
    public static func formattedAmount(_ original: String) -> String {
        if let decimal = Decimal(string: original, locale: .enUSPOSIX), let string = numberFormatter.string(from: decimal as NSDecimalNumber) {
            return string
        } else {
            Logger.general.warn(category: "AmountFormatter", message: "Invalid amount: \(original)")
            reporter.report(error: Error.invalidAmount(original))
            return original
        }
    }
    
    public static func isValid(_ amount: String) -> Bool {
        let parts = amount.components(separatedBy: ".")
        if parts.count == 1 {
            return true
        } else if parts.count == 2 {
            return parts[1].count <= 8
        } else {
            return false
        }
    }
    
}
