import Foundation

final class BalancedSwappableToken {
    
    let token: SwappableToken
    let decimalBalance: Decimal
    let decimalUSDPrice: Decimal
    
    var assetID: String {
        token.assetID
    }
    
    init(token: SwappableToken, balance: Decimal, usdPrice: Decimal) {
        self.token = token
        self.decimalBalance = balance
        self.decimalUSDPrice = usdPrice
    }
    
}
