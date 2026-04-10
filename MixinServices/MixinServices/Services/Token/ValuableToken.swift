import Foundation

public protocol ValuableToken: Token {
    
    var decimalBalance: Decimal { get }
    var decimalUSDPrice: Decimal { get }
    
    var decimalUSDBalance: Decimal { get }
    var localizedFiatMoneyPrice: String { get }
    var localizedBalanceWithSymbol: String { get }
    var localizedFiatMoneyBalance: String { get }
    var estimatedFiatMoneyBalance: String { get }
    
}

extension ValuableToken {
    
    public func localizeFiatMoneyPrice() -> String {
        CurrencyFormatter.localizedString(
            from: decimalUSDPrice * Currency.current.decimalRate,
            format: .fiatMoneyPrice,
            sign: .never,
            symbol: .currencySymbol
        )
    }
    
    public func localizeBalanceWithSymbol() -> String {
        CurrencyFormatter.localizedString(
            from: decimalBalance,
            format: .precision,
            sign: .never,
            symbol: .custom(symbol)
        )
    }
    
    public func estimateFiatMoneyBalance() -> String {
        "≈ " + localizeFiatMoneyBalance()
    }
    
    public func localizeFiatMoneyBalance() -> String {
        CurrencyFormatter.localizedString(
            from: decimalUSDBalance * Currency.current.decimalRate,
            format: .fiatMoneyPrecision,
            sign: .never,
            symbol: .currencySymbol
        )
    }
    
}
