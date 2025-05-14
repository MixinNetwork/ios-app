import Foundation
import MixinServices

struct QuoteRequest {
    
    let inputMint: String
    let outputMint: String
    let amount: String
    let slippage: Int
    let source: RouteTokenSource
    
    func asParameter() -> String {
        "inputMint=\(inputMint)&outputMint=\(outputMint)&amount=\(amount)&slippage=\(slippage)&source=\(source.rawValue)"
    }
    
}
