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
    
    static func web3(
        sendToken: Web3Token,
        sendAmount: Decimal,
        sendAddress: String,
        receiveToken: SwappableToken,
        slippage: Decimal
    ) -> SwapRequest? {
        guard let sendAmount = sendToken.nativeAmount(decimalAmount: sendAmount) else {
            return nil
        }
        let inputMint = if sendToken.assetKey == Web3Token.AssetKey.sol {
            Web3Token.AssetKey.wrappedSOL
        } else {
            sendToken.assetKey
        }
        let inputAmount = Token.amountString(from: sendAmount as Decimal)
        return SwapRequest(
            payer: sendAddress,
            inputMint: inputMint,
            inputAmount: inputAmount,
            outputMint: receiveToken.address,
            slippage: Slippage(decimal: slippage).integral,
            source: receiveToken.source,
            referral: sendAddress
        )
    }
    
    static func mixin(
        sendToken: TokenItem,
        sendAmount: Decimal,
        receiveToken: SwappableToken,
        source: RouteTokenSource,
        slippage: Decimal
    ) -> SwapRequest {
        SwapRequest(
            payer: myUserId,
            inputMint: sendToken.assetID,
            inputAmount: Token.amountString(from: sendAmount),
            outputMint: receiveToken.assetID,
            slippage: Slippage(decimal: slippage).integral,
            source: source,
            referral: nil
        )
    }
    
}
