import Foundation
import MixinServices

struct QuoteRequest {
    
    let inputMint: String
    let outputMint: String
    let amount: String
    let slippage: Int
    let source: RouteTokenSource
    
    func asParameter() -> String {
        var parameter: String = "inputMint=\(inputMint)&outputMint=\(outputMint)&amount=\(amount)&slippage=\(slippage)&source=mixin"
        switch source {
        case .web3:
            parameter += "&needWithdraw=true"
        default:
            break
        }
        return parameter
    }
    
}
