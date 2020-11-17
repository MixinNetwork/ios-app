import UIKit

public class Currency {
    
    public let code: String
    public let symbol: String
    
    // TODO: Remove this compatibilily layer after all types are converted
    public var rate: Double {
        decimalRate.doubleValue
    }
    
    public private(set) var decimalRate: Decimal
    
    public var icon: UIImage {
        return UIImage(named: "CurrencyIcon/\(code)")!
    }
    
    init(code: String, symbol: String, decimalRate: Decimal) {
        self.code = code
        self.symbol = symbol
        self.decimalRate = decimalRate
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
            Currency(code: "USD", symbol: "$", decimalRate: Decimal(string: "1")!),
            Currency(code: "CNY", symbol: "¥", decimalRate: Decimal(string: "6.57")!),
            Currency(code: "JPY", symbol: "¥", decimalRate: Decimal(string: "104.59")!),
            Currency(code: "EUR", symbol: "€", decimalRate: Decimal(string: "0.8447")!),
            Currency(code: "KRW", symbol: "₩", decimalRate: Decimal(string: "1107.94")!),
            Currency(code: "HKD", symbol: "HK$", decimalRate: Decimal(string: "7.76")!),
            Currency(code: "GBP", symbol: "£", decimalRate: Decimal(string: "0.758052")!),
            Currency(code: "AUD", symbol: "A$", decimalRate: Decimal(string: "1.37")!),
            Currency(code: "SGD", symbol: "S$", decimalRate: Decimal(string: "1.35")!),
            Currency(code: "MYR", symbol: "RM", decimalRate: Decimal(string: "4.11")!)
        ]
        let rates = AppGroupUserDefaults.currencyRates
        for currency in currencies {
            guard let rate = rates[currency.code] else {
                continue
            }
            guard let decimalRate = Decimal(string: rate) else {
                continue
            }
            currency.decimalRate = decimalRate
        }
        return currencies
    }()
    
    private static var map = [String: Currency](uniqueKeysWithValues: all.map({ ($0.code, $0) }))
    
    internal static func updateRate(with monies: [FiatMoney]) {
        for money in monies {
            map[money.code]?.decimalRate = money.rate
        }
        let rates = map.mapValues({ ($0.decimalRate as NSDecimalNumber).stringValue })
        AppGroupUserDefaults.currencyRates = rates
    }
    
}
