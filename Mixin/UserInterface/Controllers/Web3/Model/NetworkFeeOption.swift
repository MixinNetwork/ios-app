import Foundation
import BigInt
import MixinServices

struct NetworkFeeOption {
    
    let gasPrice: BigUInt // In Wei
    let gasLimit: BigUInt
    let speed: String
    let cost: String // In fiat money
    let duration: String
    let gasValue: String // In cryptocurrency
    
    init?(speed: String, tokenPrice: Decimal, duration: String, gas: BigUInt, gasPrice: String, gasLimit: String) {
        guard let decimalGasPrice = Decimal(string: gasPrice, locale: .enUSPOSIX) else {
            return nil
        }
        
        let gasPriceInWei = NSDecimalNumber(decimal: decimalGasPrice)
            .multiplying(byPowerOf10: 18)
            .rounding(accordingToBehavior: nil)
        guard let gasPrice = BigUInt(gasPriceInWei.description) else {
            return nil
        }
        
        guard let decimalGas = Decimal(string: gas.description, locale: .enUSPOSIX) else {
            return nil
        }
        let decimalFee = decimalGas * decimalGasPrice
        
        guard let gasLimit = BigUInt(gasLimit) else {
            return nil
        }
        
        self.gasPrice = gasPrice
        self.speed = speed
        self.cost = CurrencyFormatter.localizedString(from: decimalFee * tokenPrice, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
        self.duration = duration
        self.gasValue = CurrencyFormatter.localizedString(from: decimalFee, format: .precision, sign: .never, symbol: nil)
        self.gasLimit = gasLimit
    }
    
}
