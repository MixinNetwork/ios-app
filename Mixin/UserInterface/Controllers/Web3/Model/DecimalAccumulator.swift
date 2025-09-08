import Foundation

struct DecimalAccumulator {
    
    private let maximumIntegerDigits: Int16
    private let maximumFractionDigits: Int16
    
    private(set) var integers: [UInt8] = [0]
    private(set) var fractions: [UInt8]? = nil
    
    var willInputFraction: Bool {
        fractions?.isEmpty ?? false
    }
    
    var decimal: Decimal {
        get {
            var result: Decimal = 0
            for (index, integer) in integers.enumerated() {
                let power = pow(10, integers.count - index - 1)
                let value = Decimal(integer) * power
                result += value
            }
            if let fractions {
                for (index, fraction) in fractions.enumerated() {
                    let power = 1 / pow(10, index + 1)
                    let value = Decimal(fraction) * power
                    result += value
                }
            }
            return result
        }
        set {
            guard newValue >= 0 else {
                integers = [0]
                fractions = nil
                return
            }
            let number = NSDecimalNumber(decimal: newValue)
            let extractIntegralPart = NSDecimalNumberHandler.extractIntegralPart
            
            var integralPart = number.rounding(accordingToBehavior: extractIntegralPart)
            var fractionalPart = number.subtracting(integralPart)
            
            if integralPart == 0 {
                integers = [0]
            } else {
                integers = []
                while integralPart != 0, integers.count < maximumIntegerDigits {
                    let quotient = integralPart.dividing(by: 10, withBehavior: extractIntegralPart)
                    let remainder = integralPart.subtracting(quotient.multiplying(by: 10))
                    let value = UInt8(truncating: remainder)
                    integers.insert(value, at: 0)
                    integralPart = quotient
                }
            }
            
            if fractionalPart.compare(0) == .orderedDescending {
                var f: [UInt8] = []
                while fractionalPart != 0, f.count < maximumFractionDigits {
                    let shifted = fractionalPart.multiplying(by: 10)
                    let significant = shifted.rounding(accordingToBehavior: extractIntegralPart)
                    let value = UInt8(truncating: significant)
                    f.append(value)
                    fractionalPart = shifted.subtracting(significant)
                }
                fractions = f
            } else {
                fractions = nil
            }
        }
    }
    
    init(precision: Int16) {
        self.maximumIntegerDigits = 38 - precision
        self.maximumFractionDigits = precision
    }
    
    static func fiatMoney() -> DecimalAccumulator {
        DecimalAccumulator(precision: 2)
    }
    
    mutating func append(value: UInt8) {
        assert(value < 10)
        if let fractions {
            if fractions.count + 1 <= maximumFractionDigits {
                self.fractions!.append(value)
            }
        } else {
            if integers == [0] {
                integers = [value]
            } else if integers.count + 1 <= maximumIntegerDigits {
                integers.append(value)
            }
        }
    }
    
    mutating func appendDecimalSeparator() {
        if fractions == nil {
            fractions = []
        }
    }
    
    mutating func deleteBackwards() {
        if let fractions {
            switch fractions.count {
            case 0:
                self.fractions = nil
            case 1:
                self.fractions = []
            default:
                self.fractions!.removeLast()
            }
        } else {
            if integers.count == 1 {
                integers = [0]
            } else {
                integers.removeLast()
            }
        }
    }
    
}
