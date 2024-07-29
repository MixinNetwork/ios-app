import Foundation

struct Slippage {
    
    let decimal: Decimal
    let integral: Int
    
    init(decimal: Decimal) {
        self.decimal = decimal
        self.integral = (decimal * 10000 as NSDecimalNumber).intValue
    }
    
}
