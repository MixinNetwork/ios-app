import UIKit

public class Currency: CustomDebugStringConvertible {
    
    public let code: String
    public let symbol: String
    public var rate: Double
    
    public var icon: UIImage {
        return UIImage(named: "Currency/\(code)")!
    }
    
    init(code: String, symbol: String, rate: Double) {
        self.code = code
        self.symbol = symbol
        self.rate = rate
    }
    
    public var debugDescription: String {
        return "<Currency: \(Unmanaged.passUnretained(self).toOpaque()), code: \(code), symbol: \(symbol), rate: \(rate)>"
    }
    
}

public extension Currency {
    
    static let currentCurrencyDidChangeNotification = Notification.Name(rawValue: "one.mixin.services.current.currency.did.change")
    
    private(set) static var current = currentCurrencyStorage {
        didSet {
            NotificationCenter.default.post(name: currentCurrencyDidChangeNotification, object: nil)
        }
    }
    
    private(set) static var all: [Currency] = {
        let currencies = [
            Currency(code: "USD", symbol: "$", rate: 1),
            Currency(code: "CNY", symbol: "¥", rate: 6.4560692),
            Currency(code: "JPY", symbol: "¥", rate: 110.0238494),
            Currency(code: "EUR", symbol: "€", rate: 0.8533881),
            Currency(code: "KRW", symbol: "₩", rate: 1173.420644),
            Currency(code: "HKD", symbol: "HK$", rate: 7.7893878),
            Currency(code: "GBP", symbol: "£", rate: 0.7289103),
            Currency(code: "AUD", symbol: "A$", rate: 1.3734184),
            Currency(code: "SGD", symbol: "S$", rate: 1.3433436),
            Currency(code: "MYR", symbol: "RM", rate: 4.180405),
            Currency(code: "PHP", symbol: "₱", rate: 50.24506),
            Currency(code: "AED", symbol: "AED ", rate: 3.6691325),
        ]
        let rates = AppGroupUserDefaults.currencyRates
        for currency in currencies {
            guard let rate = rates[currency.code] else {
                continue
            }
            currency.rate = rate
        }
        return currencies
    }()
    
    private static var map = [String: Currency](uniqueKeysWithValues: all.map({ ($0.code, $0) }))
    private static var currentCurrencyStorage: Currency {
        if let code = LoginManager.shared.account?.fiat_currency, let currency = map[code] {
            return currency
        } else {
            return all[0] // USD for default
        }
    }

    static func refreshCurrentCurrency() {
        current = currentCurrencyStorage
    }
    
    static func updateRate(with monies: [FiatMoney]) {
        for money in monies {
            map[money.code]?.rate = money.rate
        }
        let rates = map.mapValues({ $0.rate })
        AppGroupUserDefaults.currencyRates = rates
    }
    
}
