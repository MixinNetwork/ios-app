import Foundation

public class Web3Account: Codable {
    
    enum CodingKeys: String, CodingKey {
        case address = "address"
        case balance = "balance"
        case changeAbsolute = "change_absolute"
        case changePercent = "change_percent"
        case tokens = "tokens"
    }
    
    public let address: String
    public let balance: String
    public let changeAbsolute: String
    public let changePercent: String
    public let tokens: [Web3Token]
    
    public private(set) lazy var localizedFiatMoneyBalance: String = {
        let decimalBalance = Decimal(string: balance, locale: .enUSPOSIX) ?? 0
        let balance = decimalBalance * Currency.current.decimalRate
        if balance.isZero {
            return "0\(currentDecimalSeparator)00"
        } else {
            return CurrencyFormatter.localizedString(from: balance, format: .fiatMoney, sign: .never)
        }
    }()
    
}
