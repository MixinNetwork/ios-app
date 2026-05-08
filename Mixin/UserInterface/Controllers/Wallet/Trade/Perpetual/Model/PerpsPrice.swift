import Foundation

enum PerpsPrice {
    
    static func format(_ value: Decimal) -> Decimal.FormatStyle.Currency {
        .currency(code: "USD")
        .presentation(.narrow)
        .precision(value.precision)
    }
    
}
