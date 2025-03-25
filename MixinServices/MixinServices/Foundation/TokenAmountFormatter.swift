import Foundation

public enum TokenAmountFormatter {
    
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        formatter.locale = .enUSPOSIX
        formatter.usesGroupingSeparator = false
        return formatter
    }()
    
    public static func string(from decimal: Decimal) -> String {
        formatter.string(from: decimal as NSDecimalNumber) ?? "\(decimal)"
    }
    
}
