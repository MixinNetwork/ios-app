import Foundation
import MixinServices

class SwapQuoteDraft: CustomStringConvertible {
    
    let sendToken: BalancedSwappableToken
    let sendAmount: Decimal
    let receiveToken: SwappableToken
    
    var description: String {
        "<SwapQuoteDraft \(sendAmount)\(sendToken.symbol) -> \(receiveToken.symbol)>"
    }
    
    init(sendToken: BalancedSwappableToken, sendAmount: Decimal, receiveToken: SwappableToken) {
        self.sendToken = sendToken
        self.sendAmount = sendAmount
        self.receiveToken = receiveToken
    }
    
}
