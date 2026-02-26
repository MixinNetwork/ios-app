import Foundation
import MixinServices

class SwapQuoteDraft: CustomStringConvertible {
    
    let sendToken: BalancedSwapToken
    let sendAmount: Decimal
    let receiveToken: SwapToken
    
    var description: String {
        "<SwapQuoteDraft \(sendAmount)\(sendToken.symbol) -> \(receiveToken.symbol)>"
    }
    
    init(sendToken: BalancedSwapToken, sendAmount: Decimal, receiveToken: SwapToken) {
        self.sendToken = sendToken
        self.sendAmount = sendAmount
        self.receiveToken = receiveToken
    }
    
}
