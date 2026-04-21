import Foundation
import MixinServices

struct SwapRequest: Encodable {
    
    let walletId: String?
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
        walletId: String?,
        sendToken: SwapToken,
        sendAmount: Decimal,
        receiveToken: SwapToken,
        source: RouteTokenSource,
        slippage: Decimal,
        payload: String,
        withdrawalDestination: String?,
        referral: String?,
    ) {
        self.walletId = walletId
        self.payer = myUserId
        self.inputMint = sendToken.assetID
        self.inputAmount = sendAmount.formatted(
            Decimal.FormatStyle.number
                .locale(.enUSPOSIX)
                .grouping(.never)
                .sign(strategy: .never)
                .precision(.fractionLength(0...sendToken.decimals))
        )
        self.outputMint = receiveToken.assetID
        self.slippage = Slippage(decimal: slippage).integral
        self.source = source
        self.payload = payload
        self.withdrawalDestination = withdrawalDestination
        self.referral = referral
    }
    
}
