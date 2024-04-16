import Foundation

public class Web3Token: Codable {
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case name = "name"
        case symbol = "symbol"
        case iconURL = "icon_url"
        case chainID = "chain_id"
        case chainIconURL = "chain_icon_url"
        case balance = "balance"
        case price = "price"
        case absoluteChange = "change_absolute"
        case percentChange = "change_percent"
    }
    
    public let id: String
    public let name: String
    public let symbol: String
    public let iconURL: String
    public let chainID: String
    public let chainIconURL: String
    public let balance: String
    public let price: String
    public let absoluteChange: String
    public let percentChange: String
    
    public private(set) lazy var decimalBalance = Decimal(string: balance, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var decimalUSDPrice = Decimal(string: price, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var decimalPercentChange = Decimal(string: percentChange, locale: .enUSPOSIX) ?? 0
    
    public private(set) lazy var localizedChange: String = CurrencyFormatter.localizedString(from: decimalPercentChange, format: .fiatMoney, sign: .whenNegative) ?? "0\(currentDecimalSeparator)00"
    
    public private(set) lazy var localizedFiatMoneyPrice: String = {
        let value = decimalUSDPrice * Currency.current.decimalRate
        return CurrencyFormatter.localizedString(from: value, format: .fiatMoneyPrice, sign: .never, symbol: .currencySymbol)
    }()
    
    public private(set) lazy var localizedFiatMoneyBalance: String = {
        let fiatMoneyBalance = decimalBalance * decimalUSDPrice * Currency.current.decimalRate
        return CurrencyFormatter.localizedString(from: fiatMoneyBalance, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
    }()
    
}
