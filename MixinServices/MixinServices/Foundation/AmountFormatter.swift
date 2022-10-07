import Foundation

public enum AmountFormatter {
    
    enum Error: Swift.Error {
        case invalidAmount(String)
    }
    
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .enUSPOSIX
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
    
}
