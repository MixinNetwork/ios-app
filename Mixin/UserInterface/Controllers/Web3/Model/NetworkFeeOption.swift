import Foundation
import MixinServices

struct NetworkFeeOption {
    
    let gasPrice: EVMQuantity // In Wei
    let gasLimit: UInt64
    let speed: String
    let cost: String // In fiat money
    let duration: String
    let gasValue: String // In cryptocurrency
    
    init?(
        speed: String,
        tokenPrice: Decimal,
        duration: String,
        gas: UInt64,
        gasPrice: String,
        gasLimit: String,
    ) {
        guard let decimalGasPrice = Decimal(string: gasPrice, locale: .enUSPOSIX) else {
            return nil
        }
        
        let gasPriceInWei = NSDecimalNumber(decimal: decimalGasPrice)
            .multiplying(byPowerOf10: 18)
            .rounding(accordingToBehavior: nil)
        guard let gasPrice = EVMQuantity(gasPriceInWei.description) else {
            return nil
        }
        
        guard let decimalGas = Decimal(string: gas.description, locale: .enUSPOSIX) else {
            return nil
        }
        let decimalFee = decimalGas * decimalGasPrice
        
        guard let gasLimit = UInt64(gasLimit) else {
            return nil
        }
        
        self.gasPrice = gasPrice
        self.speed = speed
        self.cost = CurrencyFormatter.localizedString(from: decimalFee * tokenPrice, format: .fiatMoneyPrecision, sign: .never, symbol: .currencySymbol)
        self.duration = duration
        self.gasValue = CurrencyFormatter.localizedString(from: decimalFee, format: .precision, sign: .never, symbol: nil)
        self.gasLimit = gasLimit
    }
    
}
