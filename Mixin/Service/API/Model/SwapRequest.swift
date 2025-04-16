import Foundation
import MixinServices

struct SwapRequest: Encodable {
    
    let payer: String
    let inputMint: String
    let inputAmount: String
    let outputMint: String
    let slippage: Int
    let source: RouteTokenSource
    let referral: String?
    let payload: String?
    let withdrawalDestination: String?
    
    init(
        sendToken: SwapToken,
        sendAmount: Decimal,
        receiveToken: SwapToken,
        source: RouteTokenSource,
        slippage: Decimal,
        payload: String,
        withdrawalDestination: String?
    ) {
        self.payer = myUserId
        self.inputMint = sendToken.assetID
        self.inputAmount = TokenAmountFormatter.string(from: sendAmount)
        self.outputMint = receiveToken.assetID
        self.slippage = Slippage(decimal: slippage).integral
        self.source = source
        self.referral = nil
        self.payload = payload
        self.withdrawalDestination = withdrawalDestination
    }
    
}
