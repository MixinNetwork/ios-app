import UIKit

class Currency: CustomDebugStringConvertible {
    
    let code: String
    let symbol: String
    var rate: Double
    
    var icon: UIImage {
        return UIImage(named: "CurrencyIcon/\(code)")!
    }
    
    init(code: String, symbol: String, rate: Double) {
        self.code = code
        self.symbol = symbol
        self.rate = rate
    }
    
    var debugDescription: String {
        return "<Currency: \(Unmanaged.passUnretained(self).toOpaque()), code: \(code), symbol: \(symbol), rate: \(rate)>"
    }
    
}

extension Currency {
    
    enum UserDefaultsKey {
        static let rates = "currency_rates"
    }
    
    static let currentCurrencyDidChangeNotification = Notification.Name(rawValue: "one.mixin.ios.current.currency.did.change")
    
    static var current = currentCurrencyStorage {
        didSet {
            currentCurrencyStorage = current
            NotificationCenter.default.post(name: currentCurrencyDidChangeNotification, object: nil)
        }
    }
    
    private(set) static var all: [Currency] = {
        let currencies = [
            Currency(code: "USD", symbol: "$", rate: 1),
            Currency(code: "CNY", symbol: "¥", rate: 7.07989978790283),
            Currency(code: "JPY", symbol: "¥", rate: 106.619453430176),
            Currency(code: "EUR", symbol: "€", rate: 0.90420001745224),
            Currency(code: "KRW", symbol: "₩", rate: 1210.20495605469),
            Currency(code: "HKD", symbol: "HK$", rate: 7.84223985671997),
            Currency(code: "GBP", symbol: "£", rate: 0.819242000579834),
            Currency(code: "AUD", symbol: "A$", rate: 1.47973895072937)
        ]
        if let rates = UserDefaults.standard.dictionary(forKey: UserDefaultsKey.rates) as? [String: Double] {
            for currency in currencies {
                guard let rate = rates[currency.code] else {
                    continue
                }
                currency.rate = rate
            }
        }
        return currencies
    }()
    
    private static var map = [String: Currency](uniqueKeysWithValues: all.map({ ($0.code, $0) }))
    private static var currentCurrencyStorage: Currency {
        get {
            if let code = WalletUserDefault.shared.currencyCode, let currency = map[code] {
                return currency
            } else {
                return all[0] // USD for default
            }
        }
        set {
            WalletUserDefault.shared.currencyCode = newValue.code
        }
    }
    
    static func updateRate(with monies: [FiatMoney]) {
        for money in monies {
            map[money.code]?.rate = money.rate
        }
        let rates = map.mapValues({ $0.rate })
        UserDefaults.standard.set(rates, forKey: UserDefaultsKey.rates)
    }
    
}
