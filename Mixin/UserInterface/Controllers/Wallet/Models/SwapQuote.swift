import Foundation
import MixinServices

final class SwapQuote: SwapQuoteDraft {
    
    let receiveAmount: Decimal
    let source: RouteTokenSource
    let payload: String
    
    override var description: String {
        "<SwapQuote \(sendAmount)\(sendToken.symbol) -> \(receiveAmount)\(receiveToken.symbol)>"
    }
    
    init(
        sendToken: BalancedSwapToken, sendAmount: Decimal, receiveToken: SwapToken,
        receiveAmount: Decimal, source: RouteTokenSource, payload: String
    ) {
        self.receiveAmount = receiveAmount
        self.source = source
        self.payload = payload
        super.init(sendToken: sendToken, sendAmount: sendAmount, receiveToken: receiveToken)
    }
    
    init(draft: SwapQuoteDraft, receiveAmount: Decimal, source: RouteTokenSource, payload: String) {
        self.receiveAmount = receiveAmount
        self.source = source
        self.payload = payload
        super.init(
            sendToken: draft.sendToken,
            sendAmount: draft.sendAmount,
            receiveToken: draft.receiveToken
        )
    }
    
}
