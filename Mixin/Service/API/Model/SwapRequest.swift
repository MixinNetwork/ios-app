import Foundation
import MixinServices

struct SwapRequest: Encodable {
    
    let payer: String
    let inputMint: String
    let inputAmount: String
    let outputMint: String
    let slippage: Int
    let source: RouteTokenSource
    let payload: String?
    let withdrawalDestination: String?
    let referral: String?
    
    init(
        sendToken: SwapToken,
        sendAmount: Decimal,
        receiveToken: SwapToken,
        source: RouteTokenSource,
        slippage: Decimal,
        payload: String,
        withdrawalDestination: String?,
        referral: String?,
    ) {
        self.payer = myUserId
        self.inputMint = sendToken.assetID
        self.inputAmount = TokenAmountFormatter.string(from: sendAmount)
        self.outputMint = receiveToken.assetID
        self.slippage = Slippage(decimal: slippage).integral
        self.source = source
        self.payload = payload
        self.withdrawalDestination = withdrawalDestination
        self.referral = referral
    }
    
}
