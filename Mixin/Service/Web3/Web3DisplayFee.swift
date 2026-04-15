import Foundation
import MixinServices

class Web3DisplayFee: NetworkFee {
    
    let gasless: Bool
    let token: Web3TokenItem
    let amount: Decimal
    let fiatMoneyAmount: Decimal
    
    init(token: Web3TokenItem, amount: Decimal, gasless: Bool) {
        self.token = token
        self.amount = amount
        self.fiatMoneyAmount = amount * token.decimalUSDPrice * Currency.current.decimalRate
        self.gasless = gasless
    }
    
}
