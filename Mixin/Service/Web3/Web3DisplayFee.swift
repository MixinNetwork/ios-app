import Foundation
import MixinServices

class Web3DisplayFee {
    
    let token: Web3TokenItem
    let tokenAmount: Decimal
    let fiatMoneyAmount: Decimal
    
    init(token: Web3TokenItem, amount: Decimal) {
        self.token = token
        self.tokenAmount = amount
        self.fiatMoneyAmount = amount * token.decimalUSDPrice * Currency.current.decimalRate
    }
    
}
