import Foundation
import BigInt
import MixinServices

struct NetworkFeeOption {
    
    let gasPrice: BigUInt // In Gwei
    let speed: String
    let cost: String // In fiat money
    let duration: String
    let gasValue: String // In cryptocurrency
    
    init?(speed: String, cost: String, duration: String, gas: BigUInt, gasPrice: String) {
        guard let decimalGasPrice = Decimal(string: gasPrice, locale: .enUSPOSIX) else {
            return nil
        }
        guard let decimalGas = Decimal(string: gas.description, locale: .enUSPOSIX) else {
            return nil
        }
        let decimalFee = decimalGas * decimalGasPrice
        let gasPriceInGwei = NSDecimalNumber(decimal: decimalGasPrice).multiplying(byPowerOf10: 9).rounding(accordingToBehavior: nil)
        guard let gasPrice = BigUInt(gasPriceInGwei.description, radix: 10) else {
            return nil
        }
        self.gasPrice = gasPrice
        self.speed = speed
        self.cost = cost
        self.duration = duration
        self.gasValue = CurrencyFormatter.localizedString(from: decimalFee, format: .precision, sign: .never, symbol: nil)
    }
    
}
