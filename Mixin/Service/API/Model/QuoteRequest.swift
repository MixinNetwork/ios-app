import Foundation
import MixinServices

struct QuoteRequest: Encodable {
    
    let inputMint: String
    let outputMint: String
    let amount: Int
    let slippage: Int
    
    init?(
        pay payToken: Web3Token,
        payAmount: Decimal,
        receive receiveToken: Web3SwappableToken,
        slippage: Decimal
    ) {
        guard let payAmount = payToken.nativeAmount(decimalAmount: payAmount) else {
            return nil
        }
        self.inputMint = if payToken.assetKey == Web3Token.AssetKey.sol {
            Web3Token.AssetKey.wrappedSOL
        } else {
            payToken.assetKey
        }
        self.amount = payAmount.intValue
        self.outputMint = receiveToken.address
        self.slippage = (slippage * 10000 as NSDecimalNumber).intValue
    }
    
}
