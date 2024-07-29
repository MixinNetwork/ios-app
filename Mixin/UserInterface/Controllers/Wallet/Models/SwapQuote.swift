import Foundation
import MixinServices

struct SwapQuote {
    
    let sendToken: TokenItem
    let sendAmount: Decimal
    let receiveToken: SwappableToken
    let receiveAmount: Decimal
    
    func updated(receiveAmount: Decimal) -> SwapQuote {
        SwapQuote(sendToken: self.sendToken,
                  sendAmount: self.sendAmount,
                  receiveToken: self.receiveToken,
                  receiveAmount: receiveAmount)
    }
    
}
