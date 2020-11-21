import UIKit

public class Currency {
    
    public let code: String
    public let symbol: String
    
    public private(set) var rate: Decimal
    
    public var icon: UIImage {
        UIImage(named: "CurrencyIcon/\(code)")!
    }
    
    init(code: String, symbol: String, rate: Decimal) {
        self.code = code
        self.symbol = symbol
        self.rate = rate
    }
    
}

extension Currency: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        return "<Currency: \(Unmanaged.passUnretained(self).toOpaque()), code: \(code), symbol: \(symbol), rate: \(rate)>"
    }
    
}

extension Currency {
    
    public static var current: Currency {
        if let code = LoginManager.shared.account?.fiat_currency, let currency = map[code] {
            return currency
        } else {
            return all[0] // USD for default
        }
    }
    
    public private(set) static var all: [Currency] = {
        let currencies = [
            Currency(code: "USD", symbol: "$", rate: Decimal(string: "1")!),
            Currency(code: "CNY", symbol: "¥", rate: Decimal(string: "6.57")!),
            Currency(code: "JPY", symbol: "¥", rate: Decimal(string: "104.59")!),
            Currency(code: "EUR", symbol: "€", rate: Decimal(string: "0.8447")!),
            Currency(code: "KRW", symbol: "₩", rate: Decimal(string: "1107.94")!),
            Currency(code: "HKD", symbol: "HK$", rate: Decimal(string: "7.76")!),
            Currency(code: "GBP", symbol: "£", rate: Decimal(string: "0.758052")!),
            Currency(code: "AUD", symbol: "A$", rate: Decimal(string: "1.37")!),
            Currency(code: "SGD", symbol: "S$", rate: Decimal(string: "1.35")!),
            Currency(code: "MYR", symbol: "RM", rate: Decimal(string: "4.11")!)
        ]
        let rates = AppGroupUserDefaults.currencyRates
        for currency in currencies {
            guard let rate = rates[currency.code] else {
                continue
            }
            guard let decimalRate = Decimal(string: rate) else {
                continue
            }
            currency.rate = decimalRate
        }
        return currencies
    }()
    
    private static var map = [String: Currency](uniqueKeysWithValues: all.map({ ($0.code, $0) }))
    
    internal static func updateRate(with monies: [FiatMoney]) {
        for money in monies {
            map[money.code]?.rate = money.rate
        }
        let rates = map.mapValues({ ($0.rate as NSDecimalNumber).stringValue })
        AppGroupUserDefaults.currencyRates = rates
    }
    
}
