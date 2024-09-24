import Foundation
import MixinServices

class SwapQuoteDraft: CustomStringConvertible {
    
    let sendToken: TokenItem
    let sendAmount: Decimal
    let receiveToken: SwappableToken
    
    var description: String {
        "<SwapQuoteDraft \(sendAmount)\(sendToken.symbol) -> \(receiveToken.symbol)>"
    }
    
    init(sendToken: TokenItem, sendAmount: Decimal, receiveToken: SwappableToken) {
        self.sendToken = sendToken
        self.sendAmount = sendAmount
        self.receiveToken = receiveToken
    }
    
}
