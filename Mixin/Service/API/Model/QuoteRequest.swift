import Foundation
import MixinServices

struct QuoteRequest {
    
    let inputMint: String
    let outputMint: String
    let amount: String
    let slippage: Int
    let source: RouteTokenSource
    
    static func web3(
        pay payToken: Web3Token,
        payAmount: Decimal,
        receive receiveToken: SwappableToken,
        slippage: Decimal
    ) -> QuoteRequest? {
        guard let payAmount = payToken.nativeAmount(decimalAmount: payAmount) else {
            return nil
        }
        let inputMint = if payToken.assetKey == Web3Token.AssetKey.sol {
            Web3Token.AssetKey.wrappedSOL
        } else {
            payToken.assetKey
        }
        return QuoteRequest(
            inputMint: inputMint,
            outputMint: receiveToken.address,
            amount: Token.amountString(from: Decimal(payAmount.intValue)),
            slippage: Slippage(decimal: slippage).integral,
            source: receiveToken.source
        )
    }
    
    static func exin(
        pay payToken: TokenItem,
        payAmount: Decimal,
        receive receiveToken: SwappableToken,
        slippage: Decimal
    ) -> QuoteRequest {
        QuoteRequest(
            inputMint: payToken.assetID,
            outputMint: receiveToken.assetID,
            amount: Token.amountString(from: payAmount),
            slippage: Slippage(decimal: slippage).integral,
            source: .exin
        )
    }
    
}
