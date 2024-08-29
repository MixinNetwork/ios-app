import Foundation
import MixinServices

struct QuoteRequest {
    
    let inputMint: String
    let outputMint: String
    let amount: String
    let slippage: Int
    let source: RouteTokenSource
    
    static func web3(
        sendToken: Web3Token,
        sendAmount: Decimal,
        receiveToken: SwappableToken,
        slippage: Decimal
    ) -> QuoteRequest? {
        guard let payAmount = sendToken.nativeAmount(decimalAmount: sendAmount) else {
            return nil
        }
        let inputMint = if sendToken.assetKey == Web3Token.AssetKey.sol {
            Web3Token.AssetKey.wrappedSOL
        } else {
            sendToken.assetKey
        }
        return QuoteRequest(
            inputMint: inputMint,
            outputMint: receiveToken.address,
            amount: Token.amountString(from: Decimal(payAmount.intValue)),
            slippage: Slippage(decimal: slippage).integral,
            source: receiveToken.source
        )
    }
    
    static func mixin(
        sendToken: TokenItem,
        sendAmount: Decimal,
        receiveToken: SwappableToken,
        slippage: Decimal
    ) -> QuoteRequest {
        QuoteRequest(
            inputMint: sendToken.assetID,
            outputMint: receiveToken.assetID,
            amount: Token.amountString(from: sendAmount),
            slippage: Slippage(decimal: slippage).integral,
            source: receiveToken.source
        )
    }
    
    func asParameter() -> String {
        "inputMint=\(inputMint)&outputMint=\(outputMint)&amount=\(amount)&slippage=\(slippage)&source=\(source.rawValue)"
    }
    
}
