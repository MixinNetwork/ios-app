import Foundation
import MixinServices

class Web3DisplayFee {
    
    let token: Web3TokenItem
    let tokenAmount: Decimal
    let fiatMoneyAmount: Decimal
    
    init(token: Web3TokenItem, tokenAmount: Decimal, fiatMoneyAmount: Decimal) {
        self.token = token
        self.tokenAmount = tokenAmount
        self.fiatMoneyAmount = fiatMoneyAmount
    }
    
}
