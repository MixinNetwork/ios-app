import Foundation
import MixinServices

struct DepositAmountLimitation {
    
    let minimum: Decimal?
    let maximum: Decimal?
    
    init(minimum: String, maximum: String) {
        if let min = Decimal(string: minimum, locale: .enUSPOSIX), min != 0 {
            self.minimum = min
        } else {
            self.minimum = nil
        }
        if let max = Decimal(string: maximum, locale: .enUSPOSIX), max != 0 {
            self.maximum = max
        } else {
            self.maximum = nil
        }
    }
    
    func contains(value: Decimal) -> Bool {
        var contains = true
        if let minimum {
            contains = contains && value >= minimum
        }
        if let maximum {
            contains = contains && value <= maximum
        }
        return contains
    }
    
    func minimumDescription(symbol: String) -> String? {
        guard let minimum else {
            return nil
        }
        return CurrencyFormatter.localizedString(
            from: minimum,
            format: .precision,
            sign: .never,
            symbol: .custom(symbol)
        )
    }
    
    func maximumDescription(symbol: String) -> String? {
        guard let maximum else {
            return nil
        }
        return CurrencyFormatter.localizedString(
            from: maximum,
            format: .precision,
            sign: .never,
            symbol: .custom(symbol)
        )
    }
    
}

extension DepositAmountLimitation {
    
    enum CheckingResult {
        case lessThanMinimum(Decimal)
        case greaterThanMaximum(Decimal)
        case within
    }
    
    func check(value: Decimal) -> CheckingResult {
        if let minimum, value < minimum {
            .lessThanMinimum(minimum)
        } else if let maximum, value > maximum {
            .greaterThanMaximum(maximum)
        } else {
            .within
        }
    }
    
}
