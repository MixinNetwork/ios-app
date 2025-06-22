import UIKit

public class Currency: CustomDebugStringConvertible {
    
    public let code: String
    public let symbol: String
    public let precision: Int
    public var rate: Double
    
    public var icon: UIImage {
        return UIImage(named: "Currency/\(code)")!
    }
    
    public var decimalRate: Decimal {
        // TODO: Init with decimal value and derives double value
        Decimal(rate)
    }
    
    init(code: String, symbol: String, precision: Int, rate: Double) {
        self.code = code
        self.symbol = symbol
        self.precision = precision
        self.rate = rate
    }
    
    public var debugDescription: String {
        return "<Currency: \(Unmanaged.passUnretained(self).toOpaque()), code: \(code), symbol: \(symbol), rate: \(rate)>"
    }
    
}

public extension Currency {
    
    static let currentCurrencyDidChangeNotification = Notification.Name(rawValue: "one.mixin.services.current.currency.did.change")
    
    static let usd = Currency(code: "USD", symbol: "$", precision: 2, rate: 1)
    
    private(set) static var current = currentCurrencyStorage {
        didSet {
            NotificationCenter.default.post(name: currentCurrencyDidChangeNotification, object: nil)
        }
    }
    
    private(set) static var all: [Currency] = {
        let currencies = [
            .usd,
            Currency(code: "CNY", symbol: "¥",      precision: 2, rate: 7.3),
            Currency(code: "JPY", symbol: "¥",      precision: 0, rate: 147.7),
            Currency(code: "EUR", symbol: "€",      precision: 2, rate: 0.937315),
            Currency(code: "KRW", symbol: "₩",      precision: 0, rate: 1325.47),
            Currency(code: "HKD", symbol: "HK$",    precision: 2, rate: 7.82),
            Currency(code: "GBP", symbol: "£",      precision: 2, rate: 0.807872),
            Currency(code: "AUD", symbol: "A$",     precision: 2, rate: 1.56),
            Currency(code: "SGD", symbol: "S$",     precision: 2, rate: 1.36),
            Currency(code: "MYR", symbol: "RM",     precision: 2, rate: 4.69),
            Currency(code: "PHP", symbol: "₱",      precision: 2, rate: 56.68),
            Currency(code: "AED", symbol: "AED ",   precision: 2, rate: 3.67),
            Currency(code: "TWD", symbol: "NT$",    precision: 2, rate: 31.96),
            Currency(code: "CAD", symbol: "C$",     precision: 2, rate: 1.35),
            Currency(code: "IDR", symbol: "Rp",     precision: 2, rate: 15379.57),
            Currency(code: "VND", symbol: "₫",      precision: 0, rate: 24388),
            Currency(code: "TRY", symbol: "₺",      precision: 2, rate: 27.02),
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
    
    private(set) static var map = [String: Currency](uniqueKeysWithValues: all.map({ ($0.code, $0) }))
    
    private static var currentCurrencyStorage: Currency {
        if let code = LoginManager.shared.account?.fiatCurrency, let currency = map[code] {
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
