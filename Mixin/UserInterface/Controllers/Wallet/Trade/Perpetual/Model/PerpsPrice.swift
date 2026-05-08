import Foundation

enum PerpsPrice {
    
    static let precision = 8
    
    static func format(_ value: Decimal) -> Decimal.FormatStyle.Currency {
        .currency(code: "USD")
        .presentation(.narrow)
        .precision(value.precision)
    }
    
}
