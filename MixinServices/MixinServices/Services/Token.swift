import Foundation

public protocol Token {
    
    var assetID: String { get }
    var name: String { get }
    var symbol: String { get }
    var decimalBalance: Decimal { get }
    var decimalUSDPrice: Decimal { get }
    
    var decimalUSDBalance: Decimal { get }
    var localizedFiatMoneyPrice: String { get }
    
}

extension Token {
    
    public func localizeFiatMoneyPrice() -> String {
        CurrencyFormatter.localizedString(
            from: decimalUSDPrice * Currency.current.decimalRate,
            format: .fiatMoneyPrice,
            sign: .never,
            symbol: .currencySymbol
        )
    }
    
}
