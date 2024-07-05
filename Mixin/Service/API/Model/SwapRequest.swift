import Foundation
import MixinServices

struct SwapRequest: Encodable {
    
    let payer: String
    let inputMint: String
    let inAmount: Int
    let outputMint: String
    let slippage: Int
    let source: String
    let referral: String
    
    init?(
        pay payToken: Web3Token,
        payAmount: Decimal,
        payAddress: String,
        receive receiveToken: Web3SwappableToken,
        slippage: Decimal
    ) {
        guard let inAmount = payToken.nativeAmount(decimalAmount: payAmount) else {
            return nil
        }
        self.payer = payAddress
        self.inputMint = payToken.assetKey
        self.inAmount = inAmount.intValue
        self.outputMint = receiveToken.address
        self.slippage = (slippage * 10000 as NSDecimalNumber).intValue
        self.source = receiveToken.source
        self.referral = payAddress
    }
    
}
